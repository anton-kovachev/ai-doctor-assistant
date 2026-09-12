# AI Doctor Assistant — SaaS Starter

This repository contains a small SaaS-style demo: a Next.js frontend with a FastAPI backend that serves a static Next.js export, plus Terraform for cloud infrastructure and Docker for local testing. The app demonstrates integrating authentication (Clerk), LLM provider configuration (OpenAI, Anthropic, OpenRouter), email delivery, and deployment packaging for containerized/cloud platforms.

**Business Case**
- **Problem:** Speed up prototyping of AI-enabled clinical assistant apps that require simple web UI, secure auth, and cloud deployment.
- **Value:** Provides a reproducible starter that ties together authentication, LLM providers, and a deployable build pipeline so teams can focus on domain logic, not infra wiring.

**Key Features**
- **Next.js frontend**: Modern React + SSR/static export support.
- **FastAPI backend**: Serves API endpoints, health checks, and the static frontend export via a single container port.
- **Auth (Clerk)**: Example integration and config via environment variables.
- **LLM provider pluggable**: Environment-driven configuration for OpenAI, Anthropic, and OpenRouter.
- **Terraform**: Declarative infra templates and variables.
- **Docker**: Multi-stage build that compiles the Next app and packages FastAPI to run as one container.

**Tech Stack**
- **Frontend:** Next.js 16, React 19, Tailwind CSS
- **Backend:** Python 3.12, FastAPI, Uvicorn
- **Infrastructure:** Terraform
- **Containerization:** Docker multi-stage build
- **Auth:** Clerk
- **LLM Providers:** OpenAI, Anthropic, OpenRouter

**Repository Layout**
- `api/` — FastAPI app and server entrypoint.
- `pages/`, `public/`, `styles/` — Next.js app.
- `terraform/` — Terraform configs and variables.
- `Dockerfile` — Multi-stage Dockerfile that builds the Next app and packages it with the Python server.
- `requirements.txt` — Python dependencies.
- `package.json` — Node dependencies and scripts.

**Quick Start — Prerequisites**
- Install Node.js (20+) and npm
- Install Python 3.12 and pip
- Install Docker (for container runs)
- Install Terraform (if deploying infra)

**Local Development — Frontend**
1. Install Node deps:

```bash
npm ci
```

2. Run Next dev server on port 3000 (or override `PORT`):

```bash
# one-off
PORT=4000 npm run dev
# or
npm run dev -- -p 4000
# or directly
npx next dev -p 4000
```

**Local Development — Backend (FastAPI)**
1. Create and activate a Python venv, then install:

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Run the server:

```bash
uvicorn server:app --host 0.0.0.0 --port 8000
```

The project's Dockerfile builds the Next static export and serves it from the FastAPI container on port 8000.

**Running with Docker**
1. Build the image:

```bash
docker build -t ai-doctor-assistant:local .
```

2. Run and publish port 8000 to host 8000:

```bash
docker run --rm -p 8000:8000 ai-doctor-assistant:local
```

Access the app at `http://localhost:8000/`.

**Terraform / Secrets**
- An example variables file is provided at `terraform/terraform.tvars.example`. Copy it to `terraform/terraform.tvars` and populate real values.
- The real `terraform/terraform.tvars` is ignored by `.gitignore` to avoid committing secrets.
- Keep secrets out of source control and prefer a secret manager for production deployments.

**Environment variables**
- The project reads multiple secrets via environment variables (Clerk keys, OpenAI/Anthropic keys, email credentials). A local `.env` is supported for development but avoid committing it.
- Example variable names are shown in `terraform/variables.tf` and the example `.tvars` file.

**Backend URL configuration**
- The frontend reads `NEXT_PUBLIC_BACKEND_URL` at build/runtime to determine the API base URL used by client code.
- Where to set it:
	- Local dev: create `.env.local` or add to your `.env` (this repo ignores `.env`), e.g. `NEXT_PUBLIC_BACKEND_URL="http://localhost:8000"`.
	- One-off dev run: `NEXT_PUBLIC_BACKEND_URL="http://localhost:8000" npm run dev`.
	- Build (CI): set `NEXT_PUBLIC_BACKEND_URL` in your CI environment before `npm run build` so the value is inlined into the static build.
	- Docker: container exposes the backend on port `8000`; map host ports via `-p HOST:8000` and point the frontend `NEXT_PUBLIC_BACKEND_URL` to the deployed backend URL.
	- Terraform: example variable `next_public_backend_url` is in `terraform/terraform.tvars.example` — copy it into `terraform/terraform.tvars` and populate for each environment.

**How it works**
- `next.config.ts` reads `.env` at build time and exposes `NEXT_PUBLIC_BACKEND_URL` to client code. Client pages (e.g., `pages/product.tsx`) will use `process.env.NEXT_PUBLIC_BACKEND_URL` and fall back to a relative `/api/` path for same-origin deployments.


**Changing the Service Port**
- Locally, use `PORT` env or Next/uvicorn `-p/--port` flags. In Docker the container exposes port `8000` (FastAPI) by default. Map host ports with `-p HOST:8000` when running the container.

**Security & Best Practices**
- Do not commit secrets to Git. Use `.gitignore` (already updated) and environment-based secret injection in CI/CD.
- For production, store credentials in a managed secret store and restrict IAM/service roles.
- Run static analysis and linting before commits (`npm run lint`, Python linters can be added).

**Contributing**
- Open issues and PRs for bugs or feature requests.
- Follow the repo style for code, and keep changes minimal and focused.

**Maintainers / Contact**
- Primary contact: repository owner (email shown in project envs).

**License**
- (Add your project's license here.)

---

If you'd like, I can also:
- Add a `Makefile` with common tasks,
- Create a `docs/` folder with a deployment checklist, or
- Auto-generate `terraform/terraform.tvars` from the current `.env` (keeps secrets locally).
This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/pages/api-reference/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `pages/index.tsx`. The page auto-updates as you edit the file.

[API routes](https://nextjs.org/docs/pages/building-your-application/routing/api-routes) can be accessed on [http://localhost:3000/api/hello](http://localhost:3000/api/hello). This endpoint can be edited in `pages/api/hello.ts`.

The `pages/api` directory is mapped to `/api/*`. Files in this directory are treated as [API routes](https://nextjs.org/docs/pages/building-your-application/routing/api-routes) instead of React pages.

This project uses [`next/font`](https://nextjs.org/docs/pages/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn-pages-router) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/pages/building-your-application/deploying) for more details.
