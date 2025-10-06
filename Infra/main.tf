terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  effective_bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.project_name}-site"
  effective_log_bucket  = var.log_bucket_name != "" ? var.log_bucket_name : "${var.project_name}-logs"
  common_tags           = merge({ Project = var.project_name }, var.tags)
}

# --- S3: content bucket (private, CF-only access) ---
resource "aws_s3_bucket" "site" {
  bucket = local.effective_bucket_name
  tags   = local.common_tags
}

# Keep ownership sane for modern S3
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block public access at bucket level
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional logging bucket
resource "aws_s3_bucket" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = local.effective_log_bucket
  tags   = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = var.enable_logging ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- CloudFront: use OAI so the bucket can stay private ---
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.project_name} OAI"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  price_class         = var.price_class
  is_ipv6_enabled     = true
  comment             = "${var.project_name} static site"
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-origin-${aws_s3_bucket.site.id}"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.oai.id}"
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    # Use managed cache & origin request policies for static sites
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # Managed-CORS-S3Origin
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Flexible cert handling: use ACM if provided; otherwise CF default cert
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
  }

  logging_config {
    count          = var.enable_logging
    include_cookies = false
    bucket          = var.enable_logging ? "${aws_s3_bucket.logs[0].bucket_domain_name}" : null
    prefix          = var.enable_logging ? "cloudfront/" : null
  }

  tags = local.common_tags
}

# Allow CloudFront (via OAI) to read from the bucket
data "aws_iam_policy_document" "site_policy" {
  statement {
    sid     = "AllowCloudFrontOAIRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.site.arn}/*"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_policy.json
}