import json
import logging
import os
from pathlib import Path
import sys
from dotenv import load_dotenv

if not os.getenv("AWS_LAMBDA_FUNCTION_NAME") and not os.getenv(
    "AWS_LAMBDA_RUNTIME_API"
):
    load_dotenv(dotenv_path=Path(__file__).with_name(".env.local"))

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,
)

from fastapi import Depends, FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi_clerk_auth import (
    ClerkConfig,
    ClerkHTTPBearer,
    HTTPAuthorizationCredentials,
)

from agents import (
    Runner,
    RunState,
    SessionSettings,
    trace,
)
from agents.items import TResponseInputItem
from agents.extensions.memory import RedisSession
from contextlib import AsyncExitStack, asynccontextmanager

from mcps import get_healthcare_mcp_servers
import uuid
import redis
from models import Visit, Confirmation
from system_agents.doctor_agent import configure_doctor_agent
from utils import stream_agent_events

REDIS_DEFAULT_HOST = "localhost"
REDIS_DEFAULT_PORT = 6379
REDIS_TLS_ENABLED = os.getenv("REDIS_TLS_ENABLED", "false").lower() == "true"


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncExitStack() as async_stack:
        healthcare_servers = [
            await async_stack.enter_async_context(server)
            for server in get_healthcare_mcp_servers()
        ]
        app.state.healthcare_servers = healthcare_servers
        yield
        del app.state.healthcare_servers


redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", REDIS_DEFAULT_HOST),
    port=int(os.getenv("REDIS_PORT", REDIS_DEFAULT_PORT)),
    db=int(os.getenv("REDIS_DB", 0)),
    ssl=REDIS_TLS_ENABLED,
)
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


@app.post("/api/consultation", response_class=StreamingResponse)
async def consultation_summary(
    visit: Visit,
    session_id: str = Header(default=str(uuid.uuid4()), alias="X-Session-ID"),
    last_event_id: int | None = Header(default=None, alias="Last-Event-ID"),
    creds: HTTPAuthorizationCredentials = Depends(clerk_guard),
):
    user_id = creds.decoded["sub"]
    user_sessionId = f"{user_id}_{session_id}"
    redis_scheme = "rediss" if REDIS_TLS_ENABLED else "redis"
    redis_session = RedisSession.from_url(
        session_id=f"{user_id}_{session_id}",
        url=f"{redis_scheme}://{os.getenv('REDIS_HOST', REDIS_DEFAULT_HOST)}:{os.getenv('REDIS_PORT', REDIS_DEFAULT_PORT)}",
        session_settings=SessionSettings(limit=10),
    )
    doctor_agent = configure_doctor_agent(app.state.healthcare_servers)
    user_prompt = visit.to_user_prompt()
    with trace(f"Consultation Summary {user_sessionId}"):
        stream = Runner.run_streamed(
            starting_agent=doctor_agent,
            input=user_prompt,
            context=visit,
            max_turns=10,
            session=redis_session,
        )

        return StreamingResponse(
            stream_agent_events(stream, user_sessionId, redis_client),
            media_type="text/event-stream",
        )


@app.post("/api/confirmation", response_class=StreamingResponse)
async def confirm_tool_execution(
    confirmation: Confirmation,
    session_id: str = Header(default=str(uuid.uuid4()), alias="X-Session-ID"),
    last_event_id: int | None = Header(default=None, alias="Last-Event-ID"),
    creds: HTTPAuthorizationCredentials = Depends(clerk_guard),
):
    user_id = creds.decoded["sub"]
    user_sessionId = f"{user_id}_{session_id}"
    run_state_string = redis_client.get(f"run_state_interruption:{user_sessionId}")

    if run_state_string is None:
        raise HTTPException(
            status_code=404, detail="No pending action confirmations found"
        )

    if isinstance(run_state_string, bytes):
        run_state_string = run_state_string.decode("utf-8")

    try:
        stored_state = json.loads(run_state_string)
    except json.JSONDecodeError:
        stored_state = run_state_string

    if isinstance(stored_state, dict) and isinstance(
        stored_state.get("run_state"), str
    ):
        run_state_string = stored_state["run_state"]

    if not isinstance(run_state_string, str):
        raise HTTPException(
            status_code=400,
            detail="Sorry, something went wrong with the confirmations",
        )

    doctor_agent = configure_doctor_agent(app.state.healthcare_servers)

    run_state = await RunState.from_string(
        doctor_agent,
        run_state_string,
        context_deserializer=lambda data: Visit.model_validate(data),
    )
    if not run_state:
        raise HTTPException(
            status_code=400,
            detail="Sorry, something went wrong with the confirmations",
        )

    for interruption in run_state.get_interruptions():
        confirmation_tool = next(
            (
                confirmation_tool
                for confirmation_tool in confirmation.actions
                if confirmation_tool.action_name == interruption.tool_name
            ),
            None,
        )

        if confirmation_tool is not None and confirmation_tool.is_approved:
            run_state.approve(interruption)
        else:
            run_state.reject(interruption)

    with trace(f"Confirmation {user_sessionId}"):
        stream = Runner.run_streamed(doctor_agent, run_state)

    return StreamingResponse(
        stream_agent_events(stream, user_sessionId, redis_client),
        media_type="text/event-stream",
    )


@app.get("/api/health")
def health_check():
    """Health check endpoint (used for local Docker; Lambda does not invoke it)"""
    return {"status": "healthy"}
