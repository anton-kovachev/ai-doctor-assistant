# Architecture Overview

This project uses a simple two-tier architecture packaged into a single container for convenient deployment.

- Frontend: Next.js app is statically exported (`next export`/`npm run build`) and placed in `./static` during the Docker build.
- Backend: FastAPI serves API endpoints and the static frontend; Uvicorn listens on port 8000.
- Container: Docker multi-stage build compiles the frontend and installs Python deps in a smaller runtime image.
- Infrastructure: Terraform manages cloud resources and secrets should be supplied at runtime via `terraform.tvars` or a secret manager.

Flow:
1. Developer builds the Next app and the Docker image.
2. The container serves static frontend assets and responds to API calls on the same port.
3. Terraform provisions cloud infra (ECR, compute, networking).
