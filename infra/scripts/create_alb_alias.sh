#!/bin/bash
set -euxo pipefail

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
CONFIG_FILE="$PROJECT_ROOT/infra/variables/config.json"

# Get AWS profile and region from config
AWS_PROFILE=$(jq -r '.aws_profile' "$CONFIG_FILE")
AWS_ROOT_PROFILE=$(jq -r '.aws_root_profile' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
DOMAIN_NAME=$(jq -r '.dns.domain_name' "$CONFIG_FILE")

echo "Creating ALB alias for api.$DOMAIN_NAME"
echo "AWS Profile: $AWS_PROFILE"
echo "AWS Region: $AWS_REGION"

# Function to wait for ALB to be created
wait_for_alb() {
    echo "Waiting for ALB to be created by AWS Load Balancer Controller..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking for ALB..."
        
        # Get the ALB ARN from the ingress
        ALB_ARN=$(kubectl get ingress -n backend backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$ALB_ARN" ]; then
            echo "ALB found: $ALB_ARN"
            return 0
        fi
        
        echo "ALB not ready yet, waiting 30 seconds..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    echo "Timeout waiting for ALB to be created"
    return 1
}

# Function to get ALB details
get_alb_details() {
    local alb_hostname=$1
    
    echo "Getting ALB details for: $alb_hostname"
    
    # Get the ALB DNS name and zone ID
    ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?DNSName=='$alb_hostname'].DNSName" \
        --output text)
    
    ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?DNSName=='$alb_hostname'].CanonicalHostedZoneId" \
        --output text)
    
    if [ -z "$ALB_DNS_NAME" ] || [ -z "$ALB_ZONE_ID" ]; then
        echo "Failed to get ALB details"
        return 1
    fi
    
    echo "ALB DNS Name: $ALB_DNS_NAME"
    echo "ALB Zone ID: $ALB_ZONE_ID"
}

# Function to create DNS alias record
create_dns_alias() {
    local alb_dns_name=$1
    local alb_zone_id=$2
    
    echo "Creating DNS alias record for api.$DOMAIN_NAME..."
    
    # Get the hosted zone ID
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
        --profile "$AWS_ROOT_PROFILE" \
        --query "HostedZones[?Name=='$DOMAIN_NAME.'].Id" \
        --output text | sed 's/\/hostedzone\///')
    
    if [ -z "$HOSTED_ZONE_ID" ]; then
        echo "Failed to find hosted zone for $DOMAIN_NAME"
        return 1
    fi
    
    echo "Hosted Zone ID: $HOSTED_ZONE_ID"
    
    # Create the change batch for the alias record
    cat > /tmp/route53-change.json << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "api.$DOMAIN_NAME",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "$alb_zone_id",
                    "DNSName": "dualstack.$alb_dns_name",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF
    
    # Apply the DNS change
    aws route53 change-resource-record-sets \
        --profile "$AWS_ROOT_PROFILE" \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch file:///tmp/route53-change.json
    
    echo "DNS alias record created successfully!"
    echo "api.$DOMAIN_NAME now points to $alb_dns_name"
    
    # Clean up
    rm -f /tmp/route53-change.json
}

# Main execution
main() {
    echo "Starting ALB alias creation process..."
    
    # Wait for ALB to be created
    if ! wait_for_alb; then
        echo "Failed to wait for ALB creation"
        exit 1
    fi
    
    # Get the ALB hostname from the ingress
    ALB_HOSTNAME=$(kubectl get ingress -n backend backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -z "$ALB_HOSTNAME" ]; then
        echo "Failed to get ALB hostname from ingress"
        exit 1
    fi
    
    echo "ALB Hostname: $ALB_HOSTNAME"
    
    # Get ALB details
    if ! get_alb_details "$ALB_HOSTNAME"; then
        echo "Failed to get ALB details"
        exit 1
    fi
    
    # Create DNS alias record
    if ! create_dns_alias "$ALB_DNS_NAME" "$ALB_ZONE_ID"; then
        echo "Failed to create DNS alias record"
        exit 1
    fi
    
    echo "ALB alias creation completed successfully!"
    echo "Your API is now accessible at: https://api.$DOMAIN_NAME"
}

# Run the main function
main "$@" 