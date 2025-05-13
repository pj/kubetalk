terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # These values will be filled in by the bootstrap script
    bucket         = "kubetalk-terraform-state"
    key            = "accounts/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kubetalk-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Variables
variable "organization_id" {
  description = "The ID of the AWS Organization"
  type        = string
}

variable "global_ou_id" {
  description = "The ID of the Global OU"
  type        = string
}

variable "state_bucket" {
  description = "The name of the S3 bucket for Terraform state"
  type        = string
}

variable "lock_table" {
  description = "The name of the DynamoDB table for state locking"
  type        = string
}

# Create OUs for Production and Development
resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = var.organization_id
}

resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = var.organization_id
}

# Create member accounts
resource "aws_organizations_account" "prod" {
  name  = "Production"
  email = "prod@kubetalk.com"  # Replace with your email
  parent_id = aws_organizations_organizational_unit.production.id

  # Prevent the account from being deleted when running terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "dev" {
  name  = "Development"
  email = "dev@kubetalk.com"  # Replace with your email
  parent_id = aws_organizations_organizational_unit.development.id

  # Prevent the account from being deleted when running terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

# IAM policies for account management
resource "aws_iam_policy" "account_admin" {
  name        = "AccountAdmin"
  description = "Allows management of member accounts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "organizations:*",
          "account:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Outputs
output "production_ou_id" {
  description = "The ID of the Production OU"
  value       = aws_organizations_organizational_unit.production.id
}

output "development_ou_id" {
  description = "The ID of the Development OU"
  value       = aws_organizations_organizational_unit.development.id
}

output "production_account_id" {
  description = "The ID of the Production account"
  value       = aws_organizations_account.prod.id
}

output "development_account_id" {
  description = "The ID of the Development account"
  value       = aws_organizations_account.dev.id
} 