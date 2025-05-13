#!/bin/bash
set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is required but not installed. Please install it first."
    exit 1
fi

# Check if organization named KubeTalk already exists
if aws organizations list-roots --query 'Roots[?Name==`KubeTalk`]' --output text | grep -q "KubeTalk"; then
    echo "AWS Organization 'KubeTalk' already exists. Skipping creation."
else
    echo "Creating AWS Organization 'KubeTalk'..."
    aws organizations create-organization \
        --feature-set ALL \
        --aws-service-access-principals \
            sso.amazonaws.com \
            cloudtrail.amazonaws.com \
            config.amazonaws.com \
            ram.amazonaws.com \
            tagpolicies.tag.amazonaws.com \
            ipam.amazonaws.com \
        --name "KubeTalk"
fi

# Get the organization ID and root ID for KubeTalk
ORG_ID=$(aws organizations list-roots --query 'Roots[?Name==`KubeTalk`].Id' --output text)
ROOT_ID=$(aws organizations list-roots --query 'Roots[?Name==`KubeTalk`].Id' --output text)

# Create Global OU if it doesn't exist
if ! aws organizations list-parents --child-id $ROOT_ID &> /dev/null; then
    echo "Creating Global OU..."
    aws organizations create-organizational-unit \
        --parent-id $ROOT_ID \
        --name "Global"
fi

# Get the Global OU ID
GLOBAL_OU_ID=$(aws organizations list-organizational-units-for-parent \
    --parent-id $ROOT_ID \
    --query "OrganizationalUnits[?Name=='Global'].Id" \
    --output text)

# Create Infrastructure account if it doesn't exist
if ! aws organizations list-accounts --query "Accounts[?Name=='Infrastructure'].Id" --output text &> /dev/null; then
    echo "Creating Infrastructure account..."
    INFRA_ACCOUNT_ID=$(aws organizations create-account \
        --email "infra@kubetalk.com" \
        --account-name "Infrastructure" \
        --parent-id $GLOBAL_OU_ID \
        --query 'CreateAccountStatus.AccountId' \
        --output text)
    
    # Wait for account creation to complete
    echo "Waiting for Infrastructure account creation to complete..."
    aws organizations describe-create-account-status \
        --create-account-request-id $INFRA_ACCOUNT_ID \
        --query 'CreateAccountStatus.State' \
        --output text
else
    INFRA_ACCOUNT_ID=$(aws organizations list-accounts \
        --query "Accounts[?Name=='Infrastructure'].Id" \
        --output text)
fi

# Create S3 bucket for Terraform state in the Infrastructure account
BUCKET_NAME="kubetalk-terraform-state-global"
if ! aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    echo "Creating S3 bucket for Terraform state in Infrastructure account..."
    
    # Assume role in Infrastructure account
    INFRA_ROLE_ARN="arn:aws:iam::${INFRA_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
    CREDENTIALS=$(aws sts assume-role \
        --role-arn $INFRA_ROLE_ARN \
        --role-session-name "TerraformBootstrap")
    
    export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r .Credentials.AccessKeyId)
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r .Credentials.SecretAccessKey)
    export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r .Credentials.SessionToken)
    
    # Create bucket in Infrastructure account
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region us-east-1

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled

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
        }'
        
    # Create bucket policy to allow access from organization
    aws s3api put-bucket-policy \
        --bucket $BUCKET_NAME \
        --policy "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [
                {
                    \"Sid\": \"AllowOrganizationAccess\",
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"AWS\": \"arn:aws:iam::${INFRA_ACCOUNT_ID}:root\"
                    },
                    \"Action\": \"s3:*\",
                    \"Resource\": [
                        \"arn:aws:s3:::${BUCKET_NAME}\",
                        \"arn:aws:s3:::${BUCKET_NAME}/*\"
                    ]
                }
            ]
        }"
fi

# Create DynamoDB table for state locking in the Infrastructure account
TABLE_NAME="kubetalk-terraform-locks"
if ! aws dynamodb describe-table --table-name $TABLE_NAME 2>/dev/null; then
    echo "Creating DynamoDB table for state locking in Infrastructure account..."
    aws dynamodb create-table \
        --table-name $TABLE_NAME \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
fi

# Output the configuration
echo "Organization setup complete!"
echo "Organization ID: $ORG_ID"
echo "Global OU ID: $GLOBAL_OU_ID"
echo "Infrastructure Account ID: $INFRA_ACCOUNT_ID"
echo "Terraform state bucket: $BUCKET_NAME"
echo "Terraform lock table: $TABLE_NAME"

# Create a terraform.tfvars file for the global module
cat > infra/global.tfvars << EOF
organization_id = "$ORG_ID"
global_ou_id    = "$GLOBAL_OU_ID"
state_bucket    = "$BUCKET_NAME"
lock_table      = "$TABLE_NAME"
infra_account_id = "$INFRA_ACCOUNT_ID"
EOF 