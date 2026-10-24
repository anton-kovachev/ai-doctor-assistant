from pydantic import BaseModel


class PendingRun(BaseModel):
    id: str
    user_id: str
    state: str


PENDING_RUNS = []


def keep_recent_history(history, new_input):
    # Keep only the last 10 history items, then append the new turn.
    return history[-10:] + new_input
