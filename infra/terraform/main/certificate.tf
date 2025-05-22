# Route53 provider configuration
variable "aws_root_profile" {
  type = string
  description = "The AWS root profile to use for Route53"
}

provider "aws" {
  alias  = "route53"
  region = var.aws_region
  profile = var.aws_root_profile
}

# Route 53 zone
data "aws_route53_zone" "zone" {
  provider = aws.route53
  name = "${var.domain_name}."  # Note the trailing dot
}

# DNS records for certificate validation
resource "aws_route53_record" "cert_validation" {
  provider = aws.route53
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}

# ACM Certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = var.dns.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.dns.domain_name}",
    "app.${var.dns.domain_name}",
    "auth.${var.dns.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }
} 

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

// Cognito needs a separate A record for the CloudFront distribution
resource "aws_route53_record" "root_domain" {
  provider = aws.route53
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.dns.domain_name}"
  type    = "A"

  ttl     = "300"
  records = ["127.0.0.1"]
}