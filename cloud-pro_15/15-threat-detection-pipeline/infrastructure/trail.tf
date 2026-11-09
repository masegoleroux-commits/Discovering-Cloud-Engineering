# ---------- CloudTrail: the source of every event ----------
# EventBridge only receives "AWS API Call via CloudTrail" events while a trail is logging.
# One single-region trail of management events is the free first copy. If your account
# already has a trail logging in eu-north-1, set create_trail = false and that one is used.
resource "aws_s3_bucket" "trail" {
  count         = var.create_trail ? 1 : 0
  bucket        = "${local.name_prefix}-trail-${local.account_id}"
  force_destroy = true # practice project: destroy also deletes the log files
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count                   = var.create_trail ? 1 : 0
  bucket                  = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.create_trail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  count  = var.create_trail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.trail_log_days
    }
  }
}

locals {
  trail_name = "${local.name_prefix}-trail"
  trail_arn  = "arn:aws:cloudtrail:${var.aws_region}:${local.account_id}:trail/${local.trail_name}"
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.create_trail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail[0].arn
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail[0].arn}/AWSLogs/${local.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceArn" = local.trail_arn } }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.trail[0].arn, "${aws_s3_bucket.trail[0].arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })
}

resource "aws_cloudtrail" "main" {
  count                         = var.create_trail ? 1 : 0
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail[0].id
  is_multi_region_trail         = false # my account only allows eu-north-1
  include_global_service_events = false # global events (IAM, sign-in) are recorded in us-east-1, which my account can't use
  enable_log_file_validation    = true  # signed digest files prove the logs weren't edited

  depends_on = [aws_s3_bucket_policy.trail]
}
