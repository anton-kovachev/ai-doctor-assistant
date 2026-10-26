import os
from typing import cast
from openai import AsyncOpenAI
from agents import (
    Agent,
    OpenAIChatCompletionsModel,
    GuardrailFunctionOutput,
    RunContextWrapper,
    TResponseInputItem,
    input_guardrail,
)
from agents.mcp import MCPServer
from aws_bedrock_token_generator import provide_token
from tools import send_treatment_plan_email
from models import Visit
from prompts import AI_DOC_SYSTEM_PROMPT

MAX_NOTES_LENGTH = 500

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
    os.getenv("MODEL", "openai.gpt-oss-120b"), openai_client=client
)


@input_guardrail(run_in_parallel=False)
def notes_word_limit_guardrail(
    context: RunContextWrapper[Visit],
    _agent: Agent[Visit],
    _agent_input: str | list[TResponseInputItem],
) -> GuardrailFunctionOutput:
    word_count = len(context.context.notes.split())
    exceeds_limit = word_count > MAX_NOTES_LENGTH
    return GuardrailFunctionOutput(
        output_info=(
            f"Consultation notes are limited to {MAX_NOTES_LENGTH} words. Please shorten the notes and try again."
            if exceeds_limit
            else f"Consultation notes contain {word_count} words."
        ),
        tripwire_triggered=exceeds_limit,
    )


def configure_doctor_agent(healthcare_mcp_servers: list[MCPServer]) -> Agent:
    doctor_agent = Agent(
        name="Doctor",
        model=model,
        instructions=AI_DOC_SYSTEM_PROMPT,
        mcp_servers=cast(list[MCPServer], healthcare_mcp_servers),
        mcp_config={"convert_schemas_to_strict": True},
        tools=[send_treatment_plan_email],
        input_guardrails=[notes_word_limit_guardrail],
    )

    return doctor_agent
