terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Management account provider
provider "aws" {
  region = "us-east-1"
  alias  = "management"
}

# Production account provider
provider "aws" {
  region = "us-east-1"
  alias  = "prod"
  assume_role {
    role_arn = "arn:aws:iam::${module.org.prod_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Development account provider
provider "aws" {
  region = "us-east-1"
  alias  = "dev"
  assume_role {
    role_arn = "arn:aws:iam::${module.org.dev_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Call the organization module
module "org" {
  source = "./org"
  providers = {
    aws = aws.management
  }
}

# Call the static website module in production
module "static_prod" {
  source = "./static"
  providers = {
    aws = aws.prod
  }
}

# Call the static website module in development
module "static_dev" {
  source = "./static"
  providers = {
    aws = aws.dev
  }
}

# Call the registry module in production
module "registry_prod" {
  source = "./registry"
  providers = {
    aws = aws.prod
  }
}

# Call the registry module in development
module "registry_dev" {
  source = "./registry"
  providers = {
    aws = aws.dev
  }
}

# Output all important values
output "prod_cloudfront_domain" {
  value     = module.static_prod.cloudfront_domain_name
  description = "The CloudFront domain name for the production static website"
}

output "dev_cloudfront_domain" {
  value     = module.static_dev.cloudfront_domain_name
  description = "The CloudFront domain name for the development static website"
}

output "prod_registry_url" {
  value     = module.registry_prod.repository_url
  description = "The ECR repository URL for the production operator"
}

output "dev_registry_url" {
  value     = module.registry_dev.repository_url
  description = "The ECR repository URL for the development operator"
} 