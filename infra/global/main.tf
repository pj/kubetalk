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
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kubetalk-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"  # Global resources typically use us-east-1
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

# Global Route 53 zone
resource "aws_route53_zone" "global" {
  name = "kubetalk.com"  # Replace with your domain
}

# IAM policies for global resources
resource "aws_iam_policy" "global_route53_admin" {
  name        = "GlobalRoute53Admin"
  description = "Allows management of global Route 53 resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "route53:*",
          "route53domains:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Outputs
output "global_zone_id" {
  description = "The ID of the global Route 53 zone"
  value       = aws_route53_zone.global.zone_id
}

output "global_zone_name_servers" {
  description = "The name servers for the global Route 53 zone"
  value       = aws_route53_zone.global.name_servers
}

output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = var.organization_id
}

output "global_ou_id" {
  description = "The ID of the Global OU"
  value       = var.global_ou_id
} 