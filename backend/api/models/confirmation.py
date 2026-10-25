from pydantic import BaseModel


class PendingAction(BaseModel):
    action_name: str
    is_approved: bool


class Confirmation(BaseModel):
    actions: list[PendingAction]
