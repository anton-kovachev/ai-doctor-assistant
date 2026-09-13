#!/bin/bash

ENVIRONMENT=$1

echo "🗑️ Preparing to destroy ${ENVIRONMENT} infrastructure..."

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if workspace exists
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "❌ Error: Workspace '$ENVIRONMENT' does not exist"
    echo "Available workspaces:"
    terraform workspace list
    exit 1
fi

# Select the workspace
terraform workspace select "$ENVIRONMENT"

echo "📦 Emptying ECR..."

# Get AWS Account ID for bucket names
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="ai-doctor-assistant-{$ENVIRONMENT}-ecr-repository"

aws ecr list-images --repository-name "$ECR_REPO" --query 'imageIds[*].imageDigest' --output text | tr '\t' '\n' | sed 's/^/imageDigest=/' | xargs --no-run-if-empty aws ecr batch-delete-image --repository-name "$ECR_REPO" --image-ids

echo "🔥 Running terraform destroy..."

# Run terraform destroy with auto-approve
if [ "$ENVIRONMENT" = "prod" ] && [ -f "prod.tfvars" ]; then
    terraform destroy -var-file=prod.tfvars -var="environment=$ENVIRONMENT" -auto-approve
else
    terraform destroy -var-file=terraform.tfvars -var="environment=$ENVIRONMENT" -auto-approve
fi

echo "✅ Infrastructure for ${ENVIRONMENT} has been destroyed!"
echo ""
echo "💡 To remove the workspace completely, run:"
echo "   terraform workspace select default"
echo "   terraform workspace delete $ENVIRONMENT"
