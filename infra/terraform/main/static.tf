variable "static_website_bucket_name" {
  type = string
  description = "The name of the S3 bucket for static website hosting"
}

variable "domain_name" {
  type = string
  description = "The domain name of the static website"
}

variable "subdomain_name" {
  type = string
  description = "The subdomain name of the static website"
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "static_website" {
  bucket = var.static_website_bucket_name
}

# S3 bucket configuration for static website hosting
resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"  # For SPA routing
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "static_website" {
  name                              = "OAC ${aws_s3_bucket.static_website.bucket}"
  description                       = "Origin Access Control for Static Website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "static_website" {
  bucket = aws_s3_bucket.static_website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static_website.arn
          }
        }
      },
      {
        Sid       = "AllowCloudFrontListBucket"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.static_website.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static_website.arn
          }
        }
      }
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "static_website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"  # Use only North America and Europe edge locations
  aliases             = ["${var.subdomain_name}.${var.domain_name}"]  # Add your domain here

  origin {
    domain_name              = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static_website.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.static_website.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Handle SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Main A record for the website
resource "aws_route53_record" "website" {
  provider = aws.route53
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.subdomain_name}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_website.domain_name
    zone_id                = aws_cloudfront_distribution.static_website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Output the CloudFront domain name
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.static_website.domain_name
}

# Output the website URL
output "website_url" {
  value = "https://${var.subdomain_name}.${var.domain_name}"
} 

output "static_website_bucket_name" {
  value = aws_s3_bucket.static_website.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.static_website.id
}