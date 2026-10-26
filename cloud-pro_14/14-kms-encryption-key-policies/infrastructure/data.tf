# ---------- S3: every object encrypted with the key by default ----------
resource "aws_s3_bucket" "data" {
  bucket        = "${local.name_prefix}-data-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Refuse uploads that ask for a different encryption type or a different key, and plain HTTP.
# "IfExists": an upload with no encryption headers is still allowed, and the bucket default
# (this key) encrypts it.
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyOtherEncryptionTypes"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = { StringNotEqualsIfExists = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      },
      {
        Sid       = "DenyOtherKmsKeys"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = { StringNotEqualsIfExists = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.data.arn } }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.data]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true # one data key per bucket, far fewer KMS calls (and cost)
  }
}

# A synthetic "confidential" object for the access tests.
resource "aws_s3_object" "statement" {
  bucket                 = aws_s3_bucket.data.id
  key                    = "confidential/statement.txt"
  content                = "SYNTHETIC TEST DATA - account 0000000000, balance R 1 234.56\n"
  content_type           = "text/plain"
  depends_on             = [aws_s3_bucket_server_side_encryption_configuration.data, aws_s3_bucket_policy.data]
  server_side_encryption = "aws:kms"
  kms_key_id             = aws_kms_key.data.arn

}

# ---------- DynamoDB and SQS with the same key ----------
resource "aws_dynamodb_table" "records" {
  name         = "${local.name_prefix}-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "record_id"

  attribute {
    name = "record_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.data.arn
  }
}

resource "aws_sqs_queue" "events" {
  name                              = "${local.name_prefix}-events"
  kms_master_key_id                 = aws_kms_key.data.arn
  kms_data_key_reuse_period_seconds = 300
  message_retention_seconds         = 3600
}
