# Values copied from project .env
next_public_clerk_publishable_key = "pk_test_c3RpbGwteWV0aS04MTI0LmNsZXJrLmFjY291bnRzLmRldiQ"
clerk_secret_key                  = "sk_test_3UuQJfA16TF0ERJDEytbnpw1yui0oQF9JwafCN8DPJ"
clerk_jwks_url                    = "https://still-yeti-8124.clerk.accounts.dev/.well-known/jwks.json"
default_aws_region                = "eu-north-1"
aws_account_id                    = "456097556049"
api_throttle_burst_limit           = 10
api_throttle_rate_limit              = 100

# Secrets should be stored in AWS Secrets Manager and referenced by name/ARN here.
# Replace the example names with your secret names or ARNs. These values are safe
# to commit since they do not contain secret values.
openrouter_secret_name = "/ai-doctor-assistant/openrouter_api_key"
openrouter_base_url = "https://api.openrouter.ai/v1"
openai_secret_name = "/ai-doctor-assistant/openai_api_key"
anthropic_base_url = "https://api.anthropic.com/v1"
anthropic_secret_name = "/ai-doctor-assistant/anthropic_api_key"
email_smtp_server = "smtp.gmail.com"
email_app_password_secret_name = "/ai-doctor-assistant/email_app_password"
email_address = "akovachev7@gmail.com"

# Sample placeholders for required variables that have no defaults.
# These are intentionally non-secret values or empty strings so the file
# can be committed safely. Replace them with Secrets Manager names or
# real values in CI if needed.
environment = "dev"

# Legacy plaintext secret variables left intentionally empty to avoid
# forcing sensitive values in the repo. The deployment should use the
# corresponding *_secret_name variables to fetch real secrets from AWS.
openrouter_api_key = "openrouter_api_key_secret"
openai_api_key = "openai_api_key_secret"
anthropic_api_key = "anthropic_api_key_secret"
email_app_password = "email_app_password_secret"
