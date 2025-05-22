#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
CONFIG_FILE="$PROJECT_ROOT/infra/variables/config.json"

# Change to the terraform directory
cd "$PROJECT_ROOT/infra/terraform/main" || exit 1

# Get Cognito configuration from Terraform outputs
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)
DOMAIN=$(terraform output -raw cognito_domain)
CLIENT_SECRET=$(terraform output -raw cognito_client_secret)

# Update config.json with Cognito values in-place
jq -i \
    --arg user_pool_id "$USER_POOL_ID" \
    --arg client_id "$CLIENT_ID" \
    --arg domain "$DOMAIN" \
    --arg client_secret "$CLIENT_SECRET" \
    '. + {
      "cognito": {
        "user_pool_id": $user_pool_id,
        "client_id": $client_id,
        "domain": $domain,
        "client_secret": $client_secret
      }
    }' "$CONFIG_FILE"

# Create frontend .env file
cat > "$PROJECT_ROOT/frontend/.env" << EOF
VITE_COGNITO_USER_POOL_ID=$USER_POOL_ID
VITE_COGNITO_CLIENT_ID=$CLIENT_ID
VITE_COGNITO_DOMAIN=$DOMAIN
VITE_COGNITO_CLIENT_SECRET=$CLIENT_SECRET
EOF

echo "Updated Cognito configuration in $CONFIG_FILE"
echo "Created frontend environment file at $PROJECT_ROOT/frontend/.env"