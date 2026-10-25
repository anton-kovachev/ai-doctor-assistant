from agents import function_tool
import smtplib
from email.message import EmailMessage
from pathlib import Path
import os

EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_SMTP_SERVER = os.getenv("EMAIL_SMTP_SERVER")
EMAIL_APP_PASSWORD = os.getenv("EMAIL_APP_PASSWORD")


async def needs_prescription_email_approval(_ctx, params, _call_id) -> bool:
    print(f"Tool params: {params}")
    if params.get("text_body", None):
        return False
    return True


@function_tool(
    name_override="send_prescription_email",
    description_override="Send a prescription email to a patient with optional attachments.",
    needs_approval=needs_prescription_email_approval,
)
def send_prescription_email(
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str,
    attachments: list | None = None,
) -> str:
    """
    Send a prescription email to the specified patient recipient.
    Use this when a user wants to send a prescription email.

    Args:
        to_email (str, required): The patient's email address.
        subject (str, required): The subject of the prescription email most likely the complaint of the patient.
        text_body (str, required): The body content of the prescription email.
        html_body (str, required): The HTML content of the prescription email.
        attachments (list, optional): List of file paths to attach to the email. Defaults to None.
    """

    if not EMAIL_ADDRESS or not EMAIL_SMTP_SERVER or not EMAIL_APP_PASSWORD:
        return "Email configuration is missing. Please check the environment configuration."

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
        server.login(EMAIL_ADDRESS, EMAIL_APP_PASSWORD)
        server.send_message(msg)

    attachment_info = f" with {len(attachments)} attachment(s)" if attachments else ""
    return f"Email sent successfully to {to_email} with subject '{subject}'{attachment_info}"
