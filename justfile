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

# Check if Docker is running
docker-check:
    #!/usr/bin/env bash
    if ! docker info > /dev/null 2>&1; then
        echo "Error: Docker is not running" >&2
        exit 1
    fi
    echo "Docker is running"

# Build and push backend Docker image
[working-directory: "backend"]
backend-docker: docker-check version registry-login
    #!/usr/bin/env bash
    # Get repository URL from terraform output
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw api_repository_url)
    # Get version tags from version_info.json
    LATEST_TAG=$(jq -r '.version.tags.location_latest' ../infra/variables/version_info.json)
    BRANCH_TAG=$(jq -r '.version.tags.branch_latest' ../infra/variables/version_info.json)
    COMMIT_TAG=$(jq -r '.version.tags.commit' ../infra/variables/version_info.json)
    # Build and tag the image
    docker build -t $REPO_URL:$LATEST_TAG -t $REPO_URL:$BRANCH_TAG -t $REPO_URL:$COMMIT_TAG .
    # Push all tags
    docker push $REPO_URL:$LATEST_TAG
    docker push $REPO_URL:$BRANCH_TAG
    docker push $REPO_URL:$COMMIT_TAG

# AWS configuration and login
# Making me manually configure this stuff, seriously?
aws-configure:
    aws configure sso
    aws configure set profile.kubetalk.sso-session "kubetalk-session" --profile kubetalk

aws-login:
    aws sso login --profile kubetalk
    @echo "AWS SSO login successful. You can now use AWS CLI with the kubetalk profile."

registry-login:
    #!/usr/bin/env bash
    # Get region from config
    REGION=$(jq -r '.region' infra/variables/config.json)
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    REPO_URL=$(cd infra/terraform/main && terraform output -raw api_repository_url)
    echo $REPO_URL
    # Check if already logged in
    if aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $REPO_URL 2>/dev/null; then
        echo "Already logged in to ECR"
    else
        echo "Logging in to ECR..."
        aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $REPO_URL
    fi

flake-docker: docker-check version registry-login
    #!/usr/bin/env bash
    # Get repository URL from terraform output
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw api_repository_url)
    # Get version tags from version_info.json
    LATEST_TAG=$(jq -r '.version.tags.location_latest' ../infra/variables/version_info.json)
    BRANCH_TAG=$(jq -r '.version.tags.branch_latest' ../infra/variables/version_info.json)
    COMMIT_TAG=$(jq -r '.version.tags.commit' ../infra/variables/version_info.json)
    # Build and tag the image
    docker build -t $REPO_URL:$LATEST_TAG -t $REPO_URL:$BRANCH_TAG -t $REPO_URL:$COMMIT_TAG ./Dockerfile.flake
    # Push all tags
    docker push $REPO_URL:$LATEST_TAG
    docker push $REPO_URL:$BRANCH_TAG
    docker push $REPO_URL:$COMMIT_TAG

infra-globals profile region:
    ./infra/scripts/terraform_globals.sh {{profile}} {{region}}

infra-manual-steps:
    echo "Manual steps before running just infra-bootstrap:"
    echo "- Enable AWS Identity Center"
    echo "- Create 'Global' OU in AWS Organizations"
    echo "- Create an AWS account in the Global OU"
    echo "- Create a user in Identity Center"
    echo "- Create a permission set in Identity Center"
    echo "- Assign the permission set to the user"

# Create some basic things for running terraform in the infra
infra-bootstrap:
    #!/usr/bin/env bash
    # Get config values
    REGION=$(jq -r '.region' infra/variables/config.json)
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    ./infra/scripts/bootstrap.sh $AWS_PROFILE $REGION

# Generate version information
version:
    ./infra/scripts/generate_version_info.sh $(test -f infra/variables/location.json && jq -r '.location' infra/variables/location.json || echo "")

[working-directory: "infra/terraform/main"]
infra:
    terraform init -backend-config=../../variables/backend.tfbackend
    terraform apply \
        -var-file=../../variables/global.tfvars \
        -var-file=../../variables/config.tfvars

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

ci-backend-docker:
    #!/usr/bin/env bash
    REGION=$(jq -r '.region' infra/variables/config.json)
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    just infra-globals $AWS_PROFILE $REGION
    just backend-docker

# Show this help message
help:
    @just --list --unsorted 