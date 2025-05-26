
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

output "api_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "operator_repository_url" {
  value = aws_ecr_repository.operator.repository_url
}

output "bundle_repository_url" {
  value = aws_ecr_repository.bundle.repository_url
}

output "catalog_repository_url" {
  value = aws_ecr_repository.catalog.repository_url
}
