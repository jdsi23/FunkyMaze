variable "project_name" {
  description = "Short name used for tagging and defaults."
  type        = string
}

variable "region" {
  description = "AWS region for the S3 bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Exact S3 bucket name. Must be globally unique. If empty, defaults to <project_name>-site."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM cert ARN in us-east-1 for custom domain on CloudFront. Leave empty to use the default CloudFront certificate."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)."
  type        = string
  default     = "PriceClass_100"
}

variable "enable_logging" {
  description = "If true, creates a log bucket and enables CloudFront logging."
  type        = bool
  default     = false
}

variable "log_bucket_name" {
  description = "Optional explicit name for the CloudFront/S3 access logs bucket. If empty and logging is enabled, defaults to <project_name>-logs."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
