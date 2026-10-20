# Architecture Overview

The frontend and backend are built and deployed independently.

- Frontend: The Next.js Pages Router app in `frontend/` is statically exported to `frontend/out/` and uploaded to a public S3 website bucket.
- Backend: The FastAPI app in `backend/api/` runs in a Python container and serves API requests through API Gateway and Lambda.
- Infrastructure: Terraform provisions the API, container registry, Lambda resources, and frontend hosting bucket.

Deployment flow:
1. Terraform builds and pushes the backend container image, then applies the API and hosting infrastructure.
2. The deploy script builds the frontend with the deployed API Gateway URL.
3. The generated static assets are synced to the Terraform-managed S3 bucket.
