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

# ECR Repository for the operator
resource "aws_ecr_repository" "operator" {
  name                 = "kubetalk-operator"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Output the repository URL
output "repository_url" {
  value = aws_ecr_repository.operator.repository_url
}

# Output the repository ARN
output "repository_arn" {
  value = aws_ecr_repository.operator.arn
} 