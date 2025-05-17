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

resource "aws_ecr_repository" "bundle" {
  name                 = "kubetalk-operator-bundle"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "catalog" {
  name                 = "kubetalk-operator-catalog"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "kubetalk-api"
  image_tag_mutability = "IMMUTABLE"

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

output "bundle_repository" {
  value = {
    url = aws_ecr_repository.bundle.repository_url
    arn = aws_ecr_repository.bundle.arn
  }
}

output "catalog_repository" {
  value = {
    url = aws_ecr_repository.catalog.repository_url
    arn = aws_ecr_repository.catalog.arn
  }
}
