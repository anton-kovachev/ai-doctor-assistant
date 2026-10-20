#!/bin/bash
set -euo pipefail

ENVIRONMENT=${1:-dev}          # dev | test | prod
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

cd "$TERRAFORM_DIR"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-eu-north-1}
terraform init -input=false -reconfigure\
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

API_URL=$(terraform output -raw app_lambda_function_url)
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
CLERK_PUBLISHABLE_KEY=$(terraform output -raw frontend_clerk_publishable_key)

echo "Building frontend for API $API_URL..."
npm --prefix "$FRONTEND_DIR" ci
NEXT_PUBLIC_BACKEND_URL="$API_URL" \
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$CLERK_PUBLISHABLE_KEY" \
  npm --prefix "$FRONTEND_DIR" run build

echo "Uploading frontend to s3://$FRONTEND_BUCKET..."
aws s3 sync "$FRONTEND_DIR/out/" "s3://$FRONTEND_BUCKET/" --delete

echo "Frontend URL: $(terraform output -raw frontend_website_url)"