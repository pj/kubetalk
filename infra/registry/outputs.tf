output "repository_url" {
  value = aws_ecr_repository.operator.repository_url
  description = "The ECR repository URL"
}

output "repository_arn" {
  value = aws_ecr_repository.operator.arn
  description = "The ECR repository ARN"
} 