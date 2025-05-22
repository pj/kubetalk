# List available tasks
default:
    @just --list

# Frontend development tasks
[working-directory: "frontend"]
frontend-dev:
    npm run dev

[working-directory: "frontend"]
frontend-build:
    npm run build

[working-directory: "frontend"]
frontend-lint:
    npm run lint

[working-directory: "frontend"]
frontend-test:
    npm test

# Deploy frontend to S3/CloudFront
frontend-deploy: frontend-build
    #!/usr/bin/env bash
    # Get AWS profile and region from config
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    REGION=$(jq -r '.region' infra/variables/config.json)
    
    # Get the S3 bucket name from Terraform
    BUCKET_NAME=$(cd infra/terraform/main && terraform output -raw static_website_bucket_name)
    
    # Sync the build directory to S3
    aws s3 sync frontend/dist/ s3://$BUCKET_NAME/ \
        --profile $AWS_PROFILE \
        --region $REGION \
        --delete
    
    # Invalidate CloudFront cache
    DISTRIBUTION_ID=$(cd infra/terraform/main && terraform output -raw cloudfront_distribution_id)
    aws cloudfront create-invalidation \
        --distribution-id $DISTRIBUTION_ID \
        --paths "/*" \
        --profile $AWS_PROFILE \
        --region $REGION
    
    echo "Frontend deployed to https://app.kubetalk.click"

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

[working-directory: "operator"]
operator-docker-build:
    #!/usr/bin/env bash
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw operator_repository_url)
    make docker-build docker-push REPO_URL=$REPO_URL

[working-directory: "operator"]
operator-bundle-docker-build:
    #!/usr/bin/env bash
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw bundle_repository_url)
    API_REPO_URL=$(cd ../infra/terraform/main && terraform output -raw api_repository_url)
    make bundle-build bundle-push BUNDLE_REPO=$REPO_URL REPO_URL=$API_REPO_URL

[working-directory: "operator"]
operator-catalog-docker-build:
    #!/usr/bin/env bash
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw catalog_repository_url)
    API_REPO_URL=$(cd ../infra/terraform/main && terraform output -raw api_repository_url)
    BUNDLE_REPO_URL=$(cd ../infra/terraform/main && terraform output -raw bundle_repository_url)
    make catalog-build catalog-push CATALOG_REPO=$REPO_URL REPO_URL=$API_REPO_URL BUNDLE_REPO=$BUNDLE_REPO_URL

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
backend-docker: docker-check version infra-init registry-login 
    #!/usr/bin/env bash
    # Get repository URL from terraform output
    REPO_URL=$(cd ../infra/terraform/main && terraform output -raw api_repository_url)
    # Get version tags from config.json
    LATEST_TAG=$(jq -r '.version.tags.location_latest' ../infra/variables/config.json)
    BRANCH_TAG=$(jq -r '.version.tags.branch_latest' ../infra/variables/config.json)
    COMMIT_TAG=$(jq -r '.version.tags.commit' ../infra/variables/config.json)
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
    aws sso login --profile kubetalk-root
    @echo "AWS SSO login successful. You can now use AWS CLI with the kubetalk and kubetalk-root profiles."

# Configure kubectl access to EKS cluster
kube-config:
    #!/usr/bin/env bash
    # Get AWS profile and region from config
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    REGION=$(jq -r '.region' infra/variables/config.json)
    CLUSTER_NAME=$(cd infra/terraform/main && terraform output -raw cluster_name)
    
    # Update kubeconfig
    aws eks update-kubeconfig \
        --name $CLUSTER_NAME \
        --region $REGION \
        --profile $AWS_PROFILE
    
    echo "Kubectl configured for cluster: $CLUSTER_NAME"

# Scale EKS node group to 0 to save costs
[working-directory: "infra/terraform/main"]
kube-scale-down:
    #!/usr/bin/env bash
    # Get AWS profile and region from config
    AWS_PROFILE=$(jq -r '.aws_profile' ../../variables/config.json)
    REGION=$(jq -r '.region' ../../variables/config.json)
    
    # Update Terraform variables
    terraform apply \
        -var-file=../../variables/config.json \
        -var="node_desired_size=0" \
        -var="node_min_size=0" \
        -auto-approve
    
    echo "Scaling node group to 0. This may take a few minutes..."

# Scale EKS node group back to 1
[working-directory: "infra/terraform/main"]
kube-scale-up:
    #!/usr/bin/env bash
    # Get AWS profile and region from config
    AWS_PROFILE=$(jq -r '.aws_profile' ../../variables/config.json)
    REGION=$(jq -r '.region' ../../variables/config.json)
    
    # Update Terraform variables
    terraform apply \
        -var-file=../../variables/config.json \
        -var="node_desired_size=1" \
        -var="node_min_size=0" \
        -auto-approve
    
    echo "Scaling node group to 1. This may take a few minutes..."

# Scale EKS node group to 0 to save costs
[working-directory: "infra/terraform/main"]
kube-eks-destroy:
    #!/usr/bin/env bash
    # Get AWS profile and region from config
    AWS_PROFILE=$(jq -r '.aws_profile' ../../variables/config.json)
    REGION=$(jq -r '.region' ../../variables/config.json)
    
    terraform destroy \
        -var-file=../../variables/config.json \
        -target=aws_eks_cluster.main \
        -target=aws_eks_node_group.main \
        -target=aws_iam_role.eks_cluster \
        -target=aws_iam_role.eks_node_group \
        -target=aws_iam_role_policy_attachment.eks_cluster_policy \
        -target=aws_iam_role_policy_attachment.eks_worker_node_policy \
        -target=aws_iam_role_policy_attachment.eks_cni_policy \
        -target=aws_iam_role_policy_attachment.eks_container_registry_readonly \
        -target=aws_security_group.eks_nodes

    echo "EKS cluster destroyed. This may take a few minutes..."

# Show current node count
kube-node-count:
    #!/usr/bin/env bash
    cd infra/terraform/main
    terraform output node_count

registry-login:
    #!/usr/bin/env bash
    # Get region from config
    REGION=$(jq -r '.region' infra/variables/config.json)
    AWS_PROFILE=$(jq -r '.aws_profile' infra/variables/config.json)
    REPO_URL=$(cd infra/terraform/main && terraform output -raw api_repository_url)
    # Check if already logged in
    if aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $REPO_URL 2>/dev/null; then
        echo "Already logged in to ECR"
    else
        echo "Logging in to ECR..."
        aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $REPO_URL
    fi

infra-globals profile region root_profile:
    ./infra/scripts/bootstrap.sh {{profile}} {{region}} {{root_profile}}

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
    AWS_ROOT_PROFILE=$(jq -r '.aws_root_profile' infra/variables/config.json)
    ./infra/scripts/bootstrap.sh $AWS_PROFILE $REGION $AWS_ROOT_PROFILE

# Generate version information
version:
    ./infra/scripts/generate_version_info.sh \
        $(test -f infra/variables/config.json && jq -r '.location' infra/variables/config.json || echo "")

# Initialize terraform
[working-directory: "infra/terraform/main"]
infra-init:
    terraform init -backend-config=../../variables/backend.tfbackend

[working-directory: "infra/terraform/main"]
infra: infra-init
    terraform apply \
        -var-file=../../variables/config.json

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

ci-backend-docker profile region root_profile:
    #!/usr/bin/env bash
    just infra-globals {{profile}} {{region}} {{root_profile}}
    ls -la infra/variables
    just backend-docker

# Show this help message
help:
    @just --list --unsorted 