import json
import os
from pathlib import Path
from dotenv import load_dotenv

if not os.getenv("AWS_LAMBDA_FUNCTION_NAME") and not os.getenv(
    "AWS_LAMBDA_RUNTIME_API"
):
    load_dotenv(dotenv_path=Path(__file__).with_name(".env.local"))

from fastapi import Depends, FastAPI, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi_clerk_auth import (
    ClerkConfig,
    ClerkHTTPBearer,
    HTTPAuthorizationCredentials,
)
from aws_bedrock_token_generator import provide_token
from openai import AsyncOpenAI
from pydantic import BaseModel

from agents import (
    Agent,
    GuardrailFunctionOutput,
    InputGuardrailTripwireTriggered,
    OpenAIChatCompletionsModel,
    Runner,
    RunContextWrapper,
    SQLiteSession,
    RunConfig,
    input_guardrail,
    trace,
)
from agents.items import TResponseInputItem
from openai.types.responses import ResponseTextDeltaEvent
from contextlib import AsyncExitStack, asynccontextmanager
from agents.mcp import MCPServer
from typing import cast

from tools.email_tools import send_prescription_email
from mcps import get_healthcare_mcp_servers
import uuid
from utils import keep_recent_history
from agents.extensions.memory import RedisSession

MAX_NOTEST_LENGTH = 500


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncExitStack() as async_stack:
        healthcare_servers = [
            await async_stack.enter_async_context(server)
            for server in get_healthcare_mcp_servers()
        ]
        app.state.healthcare_servers = healthcare_servers
        try:
            yield
        finally:
            del app.state.healthcare_servers


app = FastAPI(lifespan=lifespan)

# Add CORS middleware (allows frontend to call backend)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Clerk authentication setup
clerk_config = ClerkConfig(jwks_url=os.getenv("CLERK_JWKS_URL"))
clerk_guard = ClerkHTTPBearer(clerk_config)


class Visit(BaseModel):
    patient_name: str
    patient_email: str
    date_of_visit: str
    notes: str


@input_guardrail(run_in_parallel=False)
def notes_word_limit_guardrail(
    context: RunContextWrapper[Visit],
    _agent: Agent[Visit],
    _agent_input: str | list[TResponseInputItem],
) -> GuardrailFunctionOutput:
    word_count = len(context.context.notes.split())
    exceeds_limit = word_count > MAX_NOTEST_LENGTH
    return GuardrailFunctionOutput(
        output_info=(
            f"Consultation notes are limited to {MAX_NOTEST_LENGTH} words. Please shorten the notes and try again."
            if exceeds_limit
            else f"Consultation notes contain {word_count} words."
        ),
        tripwire_triggered=exceeds_limit,
    )


system_prompt = """
You are an AI doctor provided with health complaints of various patients.
Your job is to examine the complaints in detail and provide a detailed diagnosis of the problem alongside a detailed patient prescription.
Research about the patient's complaints with the tools your are equipped with.
Reply with exactly three sections with the headings:
### Summary the complains of the patient 
### Next steps for the doctor
### Draft of email to patient in patient-friendly language
Always send an email to the patient' email address provided in the notes section with the following format
### Email subject - the complain of the patient
### Email body - with four major sections
- ### Section 1: Diagnosis of the patient's complaintq
- ### Section 2: Recommended treatment plan for the patient
- ### Section 3: Prescribed drugs for the patient
- ### Section 4: Date of the complain and a closing greeting
"""


def user_prompt_for(visit: Visit) -> str:
    return f"""Create the summary, next steps and draft email for:
Patient Name: {visit.patient_name}
Patient Email: {visit.patient_email}
Date of Visit: {visit.date_of_visit}
Notes:
{visit.notes}"""


@app.post("/api/consultation", response_class=StreamingResponse)
async def consultation_summary(
    visit: Visit,
    session_id: str = Header(default=str(uuid.uuid4()), alias="Session-Id"),
    creds: HTTPAuthorizationCredentials = Depends(clerk_guard),
):
    with trace("Consultation Summary"):
        user_id = creds.decoded["sub"]
        project_id = os.getenv("PROJECT_ID")
        bedrock_base_url = os.getenv("AWS_BEDROCK_BASE_URL")

        if not project_id or not bedrock_base_url:
            raise ValueError("PROJECT_ID and AWS_BEDROCK_BASE_URL must be set")

        client = AsyncOpenAI(
            api_key=provide_token(),
            base_url=bedrock_base_url,
            project=project_id,
        )

        model = OpenAIChatCompletionsModel(
            model="openai.gpt-oss-120b", openai_client=client
        )

        async def event_stream():
            redis_session = RedisSession.from_url(
                f"{user_id}_{session_id}",
                url=os.getenv("REDIS_URL", default="redis://localhost:6379"),
            )
            doctor_agent = Agent(
                name="Doctor",
                model=model,
                instructions=system_prompt,
                mcp_servers=cast(list[MCPServer], app.state.healthcare_servers),
                tools=[send_prescription_email],
                input_guardrails=[notes_word_limit_guardrail],
            )

            user_prompt = user_prompt_for(visit)
            stream = Runner.run_streamed(
                starting_agent=doctor_agent,
                input=user_prompt,
                context=visit,
                max_turns=5,
                session=redis_session,
                run_config=RunConfig(session_input_callback=keep_recent_history),
            )
            try:
                async for stream_event in stream.stream_events():
                    print(f"Stream event: {stream_event}")
                    if stream_event.type == "raw_response_event" and isinstance(
                        stream_event.data, ResponseTextDeltaEvent
                    ):
                        text = stream_event.data.delta
                        if text:
                            lines = text.split("\n")
                            for line in lines[:-1]:
                                yield f"data: {line}\n\n"
                                yield "data:  \n"
                            yield f"data: {lines[-1]}\n\n"

                # if stream.interruptions:
                #     state = stream.to_state()
                #     interruptions = state.get_interruptions()
                #     print(f"Current state: {state}")
                #     print(f"Interruptions: {interruptions}")

            except InputGuardrailTripwireTriggered as exc:
                message = exc.guardrail_result.output.output_info
                if not isinstance(message, str):
                    raise
                yield f"event: error\ndata: {json.dumps({'message': message})}\n\n"

            await redis_session.close()

        return StreamingResponse(event_stream(), media_type="text/event-stream")


@app.get("/api/health")
def health_check():
    """Health check endpoint (used for local Docker; Lambda does not invoke it)"""
    return {"status": "healthy"}
