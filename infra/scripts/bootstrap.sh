#!/bin/bash
set -euxo pipefail

# Default values
AWS_PROFILE=${1:-"kubetalk"}
AWS_REGION=${2:-"us-east-1"}
AWS_ROOT_PROFILE=${3:-"kubetalk-root"}
# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is required but not installed. Please install it first."
    exit 1
fi

# Check for existing state bucket
BUCKET_PREFIX="kubetalk-terraform-state-"
EXISTING_BUCKET=$(aws s3api list-buckets --profile "${AWS_PROFILE}" --query "Buckets[?starts_with(Name, '${BUCKET_PREFIX}')].Name" --output text)
echo "EXISTING_BUCKET: $EXISTING_BUCKET"

if [ -n "$EXISTING_BUCKET" ]; then
    echo "Found existing state bucket: $EXISTING_BUCKET"
    BUCKET_NAME=$EXISTING_BUCKET
else
    # Generate new bucket name with UUID
    BUCKET_NAME="${BUCKET_PREFIX}$(uuidgen | tr -d '-')"
    echo "Creating new state bucket: $BUCKET_NAME"
    
    # Create bucket in current account
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region ${AWS_REGION} \
        --profile "${AWS_PROFILE}"

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled \
        --profile "${AWS_PROFILE}"

    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket $BUCKET_NAME \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }' \
        --profile "${AWS_PROFILE}"
fi

# Output the configuration
echo "Organization setup complete!"
echo "Terraform state bucket: $BUCKET_NAME"
echo "AWS Profile used: $AWS_PROFILE"
echo "AWS Root Profile used: $AWS_ROOT_PROFILE"

# Create a terraform.tfvars file for the global module
mkdir -p infra/variables
cat > infra/variables/global.tfvars << EOF
state_bucket = "$BUCKET_NAME"
aws_region   = "$AWS_REGION"
aws_profile  = "$AWS_PROFILE"
aws_root_profile = "$AWS_ROOT_PROFILE"
EOF

# Create a backend.tf file for the terraform state
cat > infra/variables/backend.tfbackend << EOF
bucket = "$BUCKET_NAME"
key    = "terraform.tfstate"
region = "$AWS_REGION"
profile = "$AWS_PROFILE"
use_lockfile = true
EOF
