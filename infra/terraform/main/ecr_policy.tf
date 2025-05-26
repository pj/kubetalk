data "aws_iam_policy_document" "ecr_access" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_access" {
  name        = "kubetalk-ecr-access"
  description = "Policy for accessing ECR repositories"
  policy      = data.aws_iam_policy_document.ecr_access.json
}

# Create OIDC provider for EKS
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Create IAM role for the service account
data "aws_iam_policy_document" "service_account_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:backend:backend"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "service_account" {
  name               = "kubetalk-backend-service-account"
  assume_role_policy = data.aws_iam_policy_document.service_account_assume_role.json
}

resource "aws_iam_role_policy_attachment" "service_account_ecr" {
  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.ecr_access.arn
} 

output "service_account_role_arn" {
  value = aws_iam_role.service_account.arn
}