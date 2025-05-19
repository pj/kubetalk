# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Policy for GitHub Actions
resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR permissions
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # S3 permissions for terraform state
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*"
        ]
      },
      {
        # EKS permissions
        Action = [
          "eks:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:PassRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # VPC permissions
        Action = [
          "ec2:*",
          "elasticloadbalancing:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # CloudWatch permissions
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
} 

# IAM Role for GitHub Actions Route53 Access
resource "aws_iam_role" "github_actions_route53" {
  provider = aws.route53
  name     = "github-actions-route53-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Policy for Route53 access
resource "aws_iam_role_policy" "github_actions_route53" {
  provider = aws.route53
  name     = "github-actions-route53"
  role     = aws_iam_role.github_actions_route53.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Route53 permissions
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
} 