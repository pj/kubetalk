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

# AWS configuration and login
# Making me manually configure this stuff, seriously?
aws-configure:
    aws configure sso
    aws configure set profile.kubetalk.sso-session "kubetalk-session" --profile kubetalk

aws-login:
    aws sso login --profile kubetalk
    @echo "AWS SSO login successful. You can now use AWS CLI with the kubetalk profile."

registry-login:
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(cd infra/registry && terraform output -raw repository_url)

infra-manual-steps:
    echo "Manual steps before running just infra-bootstrap:"
    echo "- Enable AWS Identity Center"
    echo "- Create 'Global' OU in AWS Organizations"
    echo "- Create an AWS account in the Global OU"
    echo "- Create a user in Identity Center"
    echo "- Create a permission set in Identity Center"
    echo "- Assign the permission set to the user"

# Create some basic things for running terraform in the infra
infra-bootstrap profile region:
    ./infra/scripts/bootstrap.sh {{profile}} {{region}}

# Generate version information
version:
    ./infra/scripts/generate_version_info.sh $(test -f infra/variables/location.json && jq -r '.location' infra/variables/location.json || echo "")

[working-directory: "infra/terraform/main"]
infra:
    terraform init -backend-config=../../variables/backend.tfbackend
    terraform apply \
        -var-file=../../variables/global.tfvars \
        -var-file=../../variables/dns.tfvars

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