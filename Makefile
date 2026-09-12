# Makefile for common tasks

.PHONY: help install deps dev build docker-build docker-run tf-init tf-apply fmt

help:
	@echo "Available targets: install, deps, dev, build, docker-build, docker-run, tf-init, tf-apply"

install: deps

deps:
	@echo "Installing Node and Python dependencies..."
	npm ci

	python -m venv .venv || true
	. .venv/bin/activate && pip install -r requirements.txt

dev:
	@echo "Run frontend and backend in development mode"
	@echo "Start frontend: npm run dev (use PORT env to change port)"
	@echo "Start backend: . .venv/bin/activate && uvicorn api.server:app --reload --port 8000"

build:
	@echo "Builds Next.js and Python packaging (for Docker)"
	npm run build

docker-build:
	@echo "Build Docker image"
	docker build -t ai-doctor-assistant:local .

docker-run:
	@echo "Run Docker container (maps host 8000 to container 8000)"
	docker run --rm -p 8000:8000 ai-doctor-assistant:local

tf-init:
	@echo "Initialize Terraform (run in terraform/ directory)"
	cd terraform && terraform init

tf-apply:
	@echo "Apply Terraform (requires terraform/terraform.tvars to exist)"
	cd terraform && terraform apply -var-file=terraform.tvars

fmt:
	@echo "Format repo files (basic)"
	# format commands can be added here
