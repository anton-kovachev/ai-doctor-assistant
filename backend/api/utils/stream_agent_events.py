import json
import logging
from collections.abc import AsyncIterator

import redis
from agents import (
    InputGuardrailTripwireTriggered,
    MessageOutputItem,
    RunItem,
    RunResultStreaming,
    ToolCallItem,
    ToolCallOutputItem,
)
from agents.items import ToolApprovalItem
from openai.types.responses import ResponseTextDeltaEvent

from .sse_event_utils import (
    _data_event,
    _error_event,
    _interruption_event,
    _progress_event,
)

logger = logging.getLogger(__name__)


def _process_interruption(interruption: ToolApprovalItem) -> dict[str, object]:
    payload: dict[str, object] = {"pending_action": interruption.tool_name}
    if interruption.tool_name != "send_treatment_plan_email":
        return payload

    raw_arguments = interruption.arguments
    if not raw_arguments:
        return payload

    try:
        arguments = json.loads(raw_arguments)
    except json.JSONDecodeError as exc:
        raise ValueError("Interrupted email tool arguments are invalid JSON") from exc

    if not isinstance(arguments, dict):
        raise ValueError("Interrupted email tool arguments must be an object")

    payload.update(
        {
            "call_id": interruption.call_id,
            "arguments": {
                "to_email": arguments.get("to_email"),
                "subject": arguments.get("subject"),
                "text_body": arguments.get("text_body"),
                "html_body": arguments.get("html_body"),
            },
        }
    )
    return payload


async def stream_agent_events(
    stream: RunResultStreaming,
    user_session_id: str,
    redis_client: redis.Redis,
) -> AsyncIterator[str]:
    event_id = 0
    try:
        async for stream_event in stream.stream_events():
            if stream_event.type == "raw_response_event" and isinstance(
                stream_event.data, ResponseTextDeltaEvent
            ):
                text = stream_event.data.delta
                if text:
                    event_id += 1
                    yield _data_event(event_id, text)
            elif stream_event.type == "run_item_stream_event" and isinstance(
                stream_event.item, RunItem
            ):
                if isinstance(stream_event.item, ToolCallItem):
                    text = (
                        f"{stream_event.item.description}"
                        if stream_event.item.description
                        else ""
                    )
                    event_id += 1
                    yield _progress_event(event_id, text)
                elif isinstance(stream_event.item, ToolCallOutputItem):
                    event_id += 1
                    yield _progress_event(event_id, f"{stream_event.item.output}")

        if stream.interruptions:
            run_state = stream.to_state()
            logger.info(
                "Saving interrupted run state for session %s",
                user_session_id,
            )
            redis_client.set(
                f"run_state_interruption:{user_session_id}",
                json.dumps({"run_state": run_state.to_string()}),
                ex=1200,
            )
            for interruption in stream.interruptions:
                event_id += 1
                yield _interruption_event(
                    event_id,
                    json.dumps(_process_interruption(interruption)),
                )
    except InputGuardrailTripwireTriggered as exc:
        message = exc.guardrail_result.output.output_info
        if not isinstance(message, str):
            raise
        event_id += 1
        yield _error_event(event_id, json.dumps({"message": message}))
