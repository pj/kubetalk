terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create the AWS Organization
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "ram.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
    "ipam.amazonaws.com"
  ]
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
  feature_set = "ALL"
}

# Create Organizational Units (OUs)
resource "aws_organizations_organizational_unit" "prod" {
  name      = "Production"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "Development"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Create member accounts
resource "aws_organizations_account" "prod" {
  name  = "Production"
  email = "prod+aws@yourdomain.com"  # Replace with your email
  parent_id = aws_organizations_organizational_unit.prod.id
}

resource "aws_organizations_account" "dev" {
  name  = "Development"
  email = "dev+aws@yourdomain.com"  # Replace with your email
  parent_id = aws_organizations_organizational_unit.dev.id
}

# Output the organization ID
output "organization_id" {
  value = aws_organizations_organization.org.id
}

# Output the account IDs
output "prod_account_id" {
  value = aws_organizations_account.prod.id
}

output "dev_account_id" {
  value = aws_organizations_account.dev.id
} 