#!/bin/bash
set -euo pipefail

ENVIRONMENT=${1:-dev}          # dev | test | prod
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-eu-north-1}
terraform init -input=false -migrate-state \
  -backend-config="bucket=ai-doctor-assistant-dev-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

# Use prod.tfvars for production environment
if [ "$ENVIRONMENT" = "prod" ]; then
  TF_APPLY_CMD=(terraform apply -var-file=prod.tfvars -var="environment=$ENVIRONMENT" -auto-approve)
else
  TF_APPLY_CMD=(terraform apply -var-file=terraform.tfvars -var="environment=$ENVIRONMENT" -auto-approve)
fi

"${TF_APPLY_CMD[@]}"