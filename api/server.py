import os
from pathlib import Path
from dotenv import load_dotenv

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi_clerk_auth import (
    ClerkConfig,
    ClerkHTTPBearer,
    HTTPAuthorizationCredentials,
)
from openai import AsyncOpenAI, OpenAI
from pydantic import BaseModel

from agents import OpenAIChatCompletionsModel, Agent, trace, Runner
from openai.types.responses import ResponseTextDeltaEvent
from contextlib import AsyncExitStack
from agents.mcp import MCPServer
from typing import cast
from tools.email_tools import send_prescription_email
from mcps import get_healthcare_mcp_servers

load_dotenv(override=True)

app = FastAPI()

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


@app.post("/api/consultation")
async def consultation_summary(
    visit: Visit,
    creds: HTTPAuthorizationCredentials = Depends(clerk_guard),
):
    with trace("Consultation Summary"):
        user_id = creds.decoded["sub"]
        anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
        anthropic_base_url = os.getenv("ANTHROPIC_BASE_URL")

        if not anthropic_api_key or not anthropic_base_url:
            raise ValueError("ANTHROPIC_API_KEY and ANTHROPIC_BASE_URL must be set")

        client = AsyncOpenAI(
            api_key=anthropic_api_key,
            base_url=anthropic_base_url,
        )

        model = OpenAIChatCompletionsModel(
            model="claude-sonnet-4-5", openai_client=client
        )

        async def event_stream():
            async with AsyncExitStack() as stack:
                healthcare_servers = [
                    await stack.enter_async_context(server)
                    for server in get_healthcare_mcp_servers()
                ]
                doctor_agent = Agent(
                    name="Doctor",
                    model=model,
                    instructions=system_prompt,
                    mcp_servers=cast(list[MCPServer], healthcare_servers),
                    tools=[send_prescription_email],
                )

                user_prompt = user_prompt_for(visit)
                stream = Runner.run_streamed(
                    starting_agent=doctor_agent, input=user_prompt, max_turns=5
                )
                async for stream_event in stream.stream_events():
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

        return StreamingResponse(event_stream(), media_type="text/event-stream")


@app.get("/health")
def health_check():
    """Health check endpoint (used for local Docker; Lambda does not invoke it)"""
    return {"status": "healthy"}


# Serve static files (our Next.js export) - MUST BE LAST!
static_path = Path("static")
if static_path.exists():

    @app.get("/")
    async def serve_root():
        return FileResponse(static_path / "index.html")

    app.mount("/", StaticFiles(directory="static", html=True), name="static")
