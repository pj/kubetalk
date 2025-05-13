output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.static_website.domain_name
  description = "The CloudFront domain name"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.static_website.bucket
  description = "The S3 bucket name"
} 