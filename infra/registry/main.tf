terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECR Repository for the operator
resource "aws_ecr_repository" "operator" {
  name                 = "kubetalk-operator"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "kubetalk-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "operator_repository" {
  value = {
    url = aws_ecr_repository.operator.repository_url
    arn = aws_ecr_repository.operator.arn
  }
}

output "api_repository" {
  value = {
    url = aws_ecr_repository.api.repository_url
    arn = aws_ecr_repository.api.arn
  }
}