import logging
import os
import smtplib
from email.message import EmailMessage
from functools import lru_cache
from pathlib import Path

import boto3
from agents import function_tool

logger = logging.getLogger(__name__)

EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_SMTP_SERVER = os.getenv("EMAIL_SMTP_SERVER")
EMAIL_APP_PASSWORD = os.getenv("EMAIL_APP_PASSWORD")
EMAIL_APP_PASSWORD_SECRET_ARN = os.getenv("EMAIL_APP_PASSWORD_SECRET_ARN")


@lru_cache(maxsize=1)
def _get_email_app_password() -> str:
    if EMAIL_APP_PASSWORD:
        return EMAIL_APP_PASSWORD

    if not EMAIL_APP_PASSWORD_SECRET_ARN:
        raise RuntimeError("Email app password is not configured")

    secrets_manager = boto3.client(
        "secretsmanager",
        region_name=os.getenv("DEFAULT_AWS_REGION") or None,
    )
    response = secrets_manager.get_secret_value(
        SecretId=EMAIL_APP_PASSWORD_SECRET_ARN
    )
    secret_value = response.get("SecretString")
    if not secret_value:
        raise RuntimeError("Email app password secret has no string value")

    return secret_value


async def needs_treatment_plan_email_approval(_ctx, params, _call_id) -> bool:
    logger.info("Evaluating approval for the treatment plan email tool")
    # if not params.get("text_body", None) or not params.get("html_body", None):
    #     return False
    return True


@function_tool(
    name_override="send_treatment_plan_email",
    description_override=(
        "Send a patient treatment-plan email containing the doctor's diagnosis, "
        "prescriptions, and personalized advice, with optional attachments."
    ),
    needs_approval=needs_treatment_plan_email_approval,
)
def send_treatment_plan_email(
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str,
    attachments: list[str] | None = None,
) -> str:
    """
    Send a treatment-plan email to the specified patient recipient.
    Include the doctor's diagnosis, prescriptions, and personalized advice.
    Always provide the recipient's email, subject, and both body formats.

    Args:
        to_email (str, required): The patient's email address.
        subject (str, required): The treatment-plan email subject.
        text_body (str, required): The plain-text treatment-plan email content.
        html_body (str, required): The HTML treatment-plan email content.
        attachments (list, optional): List of file paths to attach to the email. Defaults to None.
    """

    if not EMAIL_ADDRESS or not EMAIL_SMTP_SERVER:
        raise RuntimeError("Email sender configuration is incomplete")

    msg = EmailMessage()
    msg["From"] = EMAIL_ADDRESS
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")

    # Add attachments if provided
    if attachments:
        for attachment_path in attachments:
            file_path = Path(attachment_path)
            if file_path.exists():
                with open(file_path, "rb") as f:
                    file_data = f.read()
                    file_name = file_path.name
                    msg.add_attachment(
                        file_data,
                        maintype="application",
                        subtype="octet-stream",
                        filename=file_name,
                    )

    with smtplib.SMTP(EMAIL_SMTP_SERVER, 587) as server:
        server.starttls()
        server.login(EMAIL_ADDRESS, _get_email_app_password())
        server.send_message(msg)

    attachment_info = f" with {len(attachments)} attachment(s)" if attachments else ""
    return f"Email sent successfully to {to_email} with subject '{subject}'{attachment_info}"
