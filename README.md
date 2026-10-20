# AI Doctor Assistant — SaaS Starter

This repository contains a Next.js frontend and FastAPI backend in separate directories. The frontend is statically exported and hosted in S3; the backend is deployed separately as a container behind API Gateway.

## Structure

- `frontend/` — Next.js Pages Router app and static export configuration.
- `backend/api/` — FastAPI app, tools, and MCP integrations.
- `backend/requirements.txt` — Python dependencies.
- `terraform/` — AWS infrastructure configuration.
- `Dockerfile` — Backend-only image for local testing and Lambda deployment.

## Local development

Use `backend/.env.example` and `frontend/.env.example` as templates for their respective ignored local environment files.

Install frontend dependencies and start the frontend:

```bash
cd frontend
npm ci
npm run dev
```

Set `NEXT_PUBLIC_BACKEND_URL=http://localhost:8000` in `frontend/.env.local` for local API requests.

In another terminal, install and start the backend:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd api
uvicorn server:app --host 0.0.0.0 --port 8000
```

The frontend runs at `http://localhost:3000`; the API runs at `http://localhost:8000`.

## Docker

The Docker image contains only the backend API:

```bash
docker build -t ai-doctor-assistant:local .
docker run --rm -p 8000:8000 ai-doctor-assistant:local
```

## Deployment

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set the required values. Keep real credentials out of source control; use a secret manager for production.

Run `./scripts/deploy.sh dev` to apply the infrastructure, build the frontend with the API Gateway URL, and sync the static export to the Terraform-managed S3 website bucket. The GitHub Actions deployment workflow runs the same script.

For frontend local development, `NEXT_PUBLIC_BACKEND_URL` is read at build time. The deploy script sets it from the Terraform API Gateway output. It also uses the Clerk publishable key provided through Terraform.
