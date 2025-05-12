# List available tasks
default:
    @just --list

# Frontend development tasks
frontend-dev:
    cd frontend && npm run dev

frontend-build:
    cd frontend && npm run build

frontend-lint:
    cd frontend && npm run lint

frontend-test:
    cd frontend && npm test

# Backend development tasks
[working-directory: "backend"]
backend-dev:
    uv run uvicorn src.main:app --reload --port 8000

[working-directory: "backend"]
backend-lint:
    ruff check .

[working-directory: "backend"]
backend-test:
    pytest

# Initialize Terraform
infra-init:
    cd infra/static && terraform init

# Plan Terraform changes
infra-plan:
    cd infra/static && terraform plan

# Apply Terraform changes
infra-apply:
    cd infra/static && terraform apply

# Deploy frontend to S3/CloudFront
deploy: frontend-build
    cd infra/static && ./deploy.sh

# Initial project setup
setup:
    cd frontend && npm install
    cd backend && uv pip install -r requirements.txt
    just infra-init

# Remove build artifacts
clean:
    rm -rf frontend/dist
    find . -type d -name __pycache__ -exec rm -r {} +
    find . -type f -name '*.pyc' -delete

# Show this help message
help:
    @just --list --unsorted 