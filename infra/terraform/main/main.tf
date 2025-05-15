terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = ""
    key    = ""
    region = ""
    profile = ""
    use_lockfile = true
  }
}

variable "aws_profile" {
  description = "The AWS profile to use for authentication"
  type        = string
  default     = "kubetalk"
}

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "dns" {
  description = "DNS configuration including domain and contact information"
  type = object({
    domain_name = string
    contact = object({
      type       = string
      first_name = string
      last_name  = string
      email      = string
      phone      = string
      address = object({
        line_1       = string
        line_2       = string
        city         = string
        state        = string
        country_code = string
        zip_code     = string
      })
    })
  })
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "registry" {
  source = "../registry"
}

# TODO: This is created manually and imported
# module "dns" {
#   source = "../dns"
#   dns    = var.dns
# }
