# Deployment Checklist

This file documents steps and recommendations to deploy the application.

1. Prepare secrets
   - Copy `terraform/terraform.tvars.example` to `terraform/terraform.tvars` and fill real values.
   - Keep `terraform/terraform.tvars` out of source control.
   - Use a secrets manager for production (AWS Secrets Manager, HashiCorp Vault, etc.).

2. Build and test locally
   - Build frontend: `npm run build`
   - Run backend locally: `uvicorn api.server:app --host 0.0.0.0 --port 8000`
   - Or use Docker: `make docker-build && make docker-run`

3. Terraform infra
   - Initialize: `cd terraform && terraform init`
   - Plan: `terraform plan -var-file=terraform.tvars`
   - Apply: `terraform apply -var-file=terraform.tvars`

4. CI/CD
   - Configure your pipeline to inject secrets from your secret store, not from the repo.
   - Build Docker image in CI and push to your container registry (ECR/GCR/ACR).
   - Deploy to your environment (ECS/Fargate, EKS, or serverless adapters where appropriate).

5. Monitoring & logging
   - Configure centralized logging (CloudWatch/ELK)
   - Add health checks for the FastAPI `/health` endpoint
