# Deployment Checklist

This file documents steps and recommendations to deploy the application.

1. Prepare secrets
   - Copy `terraform/terraform.tvars.example` to `terraform/terraform.tvars` and fill real values.
   - Keep `terraform/terraform.tvars` out of source control.
   - Use a secrets manager for production (AWS Secrets Manager, HashiCorp Vault, etc.).

2. Build and test locally
   - Build frontend: `npm --prefix frontend run build`
   - Run backend locally: `cd backend/api && ../.venv/bin/uvicorn server:app --host 0.0.0.0 --port 8000`
   - Or run the backend container: `make docker-build && make docker-run`

3. Terraform infra
   - Deploy the API, build the frontend with its API URL, and upload it to S3: `./scripts/deploy.sh dev`
   - Terraform provisions the public S3 website bucket and API infrastructure.

4. CI/CD
   - Configure AWS credentials and Terraform variables through your secret store.
   - The GitHub Actions workflow runs the deployment script to deploy the backend and frontend separately.

5. Monitoring & logging
   - Configure centralized logging (CloudWatch/ELK)
   - Add health checks for the FastAPI `/api/health` endpoint
