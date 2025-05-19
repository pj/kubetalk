terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
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

variable "domain_name" {
  type = string
  description = "The domain name to register"
}

# Register the domain
resource "aws_route53domains_registered_domain" "domain" {
  domain_name = var.domain_name
  auto_renew  = false

  registrant_contact {
    contact_type  = var.dns.contact.type
    first_name    = var.dns.contact.first_name
    last_name     = var.dns.contact.last_name
    email         = var.dns.contact.email
    phone_number  = var.dns.contact.phone
    address_line_1 = var.dns.contact.address.line_1
    address_line_2 = var.dns.contact.address.line_2
    city          = var.dns.contact.address.city
    state         = var.dns.contact.address.state
    country_code  = var.dns.contact.address.country_code
    zip_code      = var.dns.contact.address.zip_code
  }

  admin_contact {
    contact_type  = var.dns.contact.type
    first_name    = var.dns.contact.first_name
    last_name     = var.dns.contact.last_name
    email         = var.dns.contact.email
    phone_number  = var.dns.contact.phone
    address_line_1 = var.dns.contact.address.line_1
    address_line_2 = var.dns.contact.address.line_2
    city          = var.dns.contact.address.city
    state         = var.dns.contact.address.state
    country_code  = var.dns.contact.address.country_code
    zip_code      = var.dns.contact.address.zip_code
  }

  tech_contact {
    contact_type  = var.dns.contact.type
    first_name    = var.dns.contact.first_name
    last_name     = var.dns.contact.last_name
    email         = var.dns.contact.email
    phone_number  = var.dns.contact.phone
    address_line_1 = var.dns.contact.address.line_1
    address_line_2 = var.dns.contact.address.line_2
    city          = var.dns.contact.address.city
    state         = var.dns.contact.address.state
    country_code  = var.dns.contact.address.country_code
    zip_code      = var.dns.contact.address.zip_code
  }
}

# Create the hosted zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Outputs
output "domain_name" {
  value = aws_route53domains_registered_domain.domain.domain_name
}

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}
