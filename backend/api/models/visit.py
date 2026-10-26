from pydantic import BaseModel


class Visit(BaseModel):
    patient_name: str
    patient_email: str
    date_of_visit: str
    notes: str

    def to_user_prompt(self) -> str:
        return f"""Create the summary, diagnosis, next steps and treatment-plan email for:
Patient Name: {self.patient_name}
Patient Email: {self.patient_email}
Date of Visit: {self.date_of_visit}
Notes:
{self.notes}"""
