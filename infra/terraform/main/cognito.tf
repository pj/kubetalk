# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "kubetalk-user-pool"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # MFA settings
  mfa_configuration = "ON"
  software_token_mfa_configuration {
    enabled = true
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # Schema attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable            = true
    required           = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Username configuration
  username_configuration {
    case_sensitive = false
  }

  # Auto verified attributes
  auto_verified_attributes = ["email"]

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Account recovery setting
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Use email as username
  username_attributes = ["email"]
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name = "kubetalk-client"

  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth 2.0 settings
  allowed_oauth_flows = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = ["email", "openid", "profile"]

  # Callback URLs
  callback_urls = ["https://app.${var.dns.domain_name}/auth/callback"]
  logout_urls   = ["https://app.${var.dns.domain_name}/logout"]

  # Token validity
  refresh_token_validity = 30
  access_token_validity  = 1
  id_token_validity     = 1

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Only use Cognito
  supported_identity_providers = ["COGNITO"]

  # Don't generate a secret for public client
  generate_secret = false

  # Enable token revocation
  enable_token_revocation = true

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]
}

locals {
  auth_domain = "auth.${var.dns.domain_name}"
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = local.auth_domain  
  user_pool_id = aws_cognito_user_pool.main.id
  certificate_arn = aws_acm_certificate.cert.arn
  depends_on = [aws_route53_record.root_domain]
}

# Cognito domain DNS record
resource "aws_route53_record" "auth" {
  provider = aws.route53
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.auth_domain
  type    = "A"

  alias {
    name                   = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
    zone_id               = "Z2FDTNDATAQYW2" # This is the fixed CloudFront hosted zone ID
    evaluate_target_health = false
  }

  depends_on = [aws_cognito_user_pool_domain.main]
}

# Outputs
output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "The domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_client_secret" {
  description = "The client secret for the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "cognito_cloudfront_distribution" {
  description = "The CloudFront distribution ARN for the Cognito domain"
  value       = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
} 