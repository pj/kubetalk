#!/bin/bash
set -euxo pipefail

# Default values
AWS_PROFILE=${1:-"kubetalk"}
AWS_REGION=${2}
AWS_ROOT_PROFILE=${3:-"kubetalk-root"}
# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is required but not installed. Please install it first."
    exit 1
fi

if [ -z "$AWS_REGION" ]; then
    echo "AWS_REGION is not set"
    exit 1
fi

# Check for existing state bucket
BUCKET_PREFIX="kubetalk-terraform-state-"
EXISTING_BUCKET=$(aws s3api list-buckets --profile "${AWS_PROFILE}" --query "Buckets[?starts_with(Name, '${BUCKET_PREFIX}')].Name" --output text)
echo "EXISTING_BUCKET: $EXISTING_BUCKET"

if [ -z "$EXISTING_BUCKET" ]; then
    echo "No existing state bucket found"
    exit 1
fi

BUCKET_NAME=$EXISTING_BUCKET

# Output the configuration
echo "Organization setup complete!"
echo "Terraform state bucket: $BUCKET_NAME"
echo "AWS Profile used: $AWS_PROFILE"

# Create a backend.tf file for the terraform state
cat << EOF > infra/variables/backend.tfbackend
bucket = "$BUCKET_NAME"
key    = "terraform.tfstate"
region = "$AWS_REGION"
profile = "$AWS_PROFILE"
use_lockfile = true
EOF

# Create or update config.json
mkdir -p infra/variables
if [ -f "infra/variables/config.json" ]; then
    # Update only the specific keys we manage
    jq --arg aws_region "$AWS_REGION" \
       --arg aws_profile "$AWS_PROFILE" \
       --arg aws_root_profile "$AWS_ROOT_PROFILE" \
       --arg state_bucket "$BUCKET_NAME" \
       '.region = $aws_region | .aws_profile = $aws_profile | .aws_root_profile = $aws_root_profile | .state_bucket = $state_bucket' \
       infra/variables/config.json > infra/variables/config.json.tmp
    mv infra/variables/config.json.tmp infra/variables/config.json
else
    # If config.json doesn't exist, create it with our managed keys
    cat << EOF > infra/variables/config.json
{
    "aws_region": "$AWS_REGION",
    "aws_profile": "$AWS_PROFILE",
    "aws_root_profile": "$AWS_ROOT_PROFILE",
    "state_bucket": "$BUCKET_NAME"
}
EOF
fi
