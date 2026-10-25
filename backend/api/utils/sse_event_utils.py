
def _format_sse_event(event_id: int, data: str, event_name: str | None = None) -> str:
    fields = [f"id: {event_id}"]
    if event_name:
        fields.append(f"event: {event_name}")
    normalized_data = data.replace("\r\n", "\n").replace("\r", "\n")
    fields.extend(f"data: {line}" for line in normalized_data.split("\n"))
    return "\n".join(fields) + "\n\n"


def _data_event(event_id: int, data: str) -> str:
    return _format_sse_event(event_id, data)


def _progress_event(event_id: int, data: str) -> str:
    return _format_sse_event(event_id, data, "progress")


def _interruption_event(event_id: int, data: str) -> str:
    return _format_sse_event(event_id, data, "interruption")


def _error_event(event_id: int, data: str) -> str:
    return _format_sse_event(event_id, data, "error")