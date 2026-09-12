// Variables corresponding to values in terraform.tvars (copied from .env)

variable "next_public_clerk_publishable_key" {
  type        = string
  description = "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY from .env"
  sensitive   = true
}

variable "clerk_secret_key" {
  type        = string
  description = "CLERK_SECRET_KEY from .env"
  sensitive   = true
}

variable "clerk_jwks_url" {
  type        = string
  description = "CLERK_JWKS_URL from .env"
}

variable "default_aws_region" {
  type        = string
  description = "DEFAULT_AWS_REGION from .env"
}

variable "aws_account_id" {
  type        = string
  description = "AWS_ACCOUNT_ID from .env"
}

variable "openrouter_api_key" {
  type        = string
  description = "OPENROUTER_API_KEY from .env"
  sensitive   = true
}

variable "openrouter_base_url" {
  type        = string
  description = "OPENROUTER_BASE_URL from .env"
}

variable "openai_api_key" {
  type        = string
  description = "OPENAI_API_KEY from .env"
  sensitive   = true
}

variable "anthropic_base_url" {
  type        = string
  description = "ANTHROPIC_BASE_URL from .env"
}

variable "anthropic_api_key" {
  type        = string
  description = "ANTHROPIC_API_KEY from .env"
  sensitive   = true
}

variable "email_smtp_server" {
  type        = string
  description = "EMAIL_SMTP_SERVER from .env"
}

variable "email_app_password" {
  type        = string
  description = "EMAIL_APP_PASSWORD from .env"
  sensitive   = true
}

variable "email_address" {
  type        = string
  description = "EMAIL_ADDRESS from .env"
}
variable "project_name" {
    description = "Name prefix for all resources"
    type        = string
      validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
  default     = "ai-doctor-assistant"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "ecr-repository"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.ecr_repository_name))
    error_message = "ECR repository name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "app_dir" {
    description = "Directory of the application"
    type        = string
    default     = "../"
}

# Instead of providing secret values directly, provide the
# Secrets Manager secret *names* (or ARNs) so Terraform can reference
# the secret without storing the secret value in tfvars or state.
variable "openrouter_secret_name" {
  type        = string
  description = "Secrets Manager name or ARN for the OpenRouter API key (e.g. /myproject/openrouter)"
  default     = ""
}

variable "openai_secret_name" {
  type        = string
  description = "Secrets Manager name or ARN for the OpenAI API key"
  default     = ""
}

variable "anthropic_secret_name" {
  type        = string
  description = "Secrets Manager name or ARN for the Anthropic API key"
  default     = ""
}

variable "email_app_password_secret_name" {
  type        = string
  description = "Secrets Manager name or ARN for the SMTP app password"
  default     = ""
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit"
  type        = number
  default     = 100
}