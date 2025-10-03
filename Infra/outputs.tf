output "bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "log_bucket_name" {
  value       = var.enable_logging ? aws_s3_bucket.logs[0].bucket : ""
  description = "Empty string if logging disabled."
}
