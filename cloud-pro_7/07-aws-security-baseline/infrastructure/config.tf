resource "aws_s3_bucket" "config" {
  count         = var.enable_config && var.create_config_recorder ? 1 : 0
  bucket        = "${local.name_prefix}-config-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  count                   = var.enable_config && var.create_config_recorder ? 1 : 0
  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count              = var.enable_config && var.create_config_recorder ? 1 : 0
  name               = "${local.name_prefix}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  count      = var.enable_config && var.create_config_recorder ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_delivery" {
  count = var.enable_config && var.create_config_recorder ? 1 : 0
  name  = "${local.name_prefix}-config-delivery"
  role  = aws_iam_role.config[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetBucketAcl"], Resource = aws_s3_bucket.config[0].arn },
      {
        Effect    = "Allow"
        Action    = ["s3:PutObject"]
        Resource  = "${aws_s3_bucket.config[0].arn}/AWSLogs/${local.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config && var.create_config_recorder ? 1 : 0
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported  = false
    resource_types = var.config_resource_types
  }
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_config && var.create_config_recorder ? 1 : 0
  name           = "${local.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].bucket
  depends_on     = [aws_config_configuration_recorder.main, aws_iam_role_policy.config_delivery]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_config && var.create_config_recorder ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

locals {
  # Rule name (shown in the console) => AWS managed rule identifier
  managed_config_rules = {
    "s3-bucket-public-read-prohibited"         = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    "s3-bucket-server-side-encryption-enabled" = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    "restricted-ssh"                           = "INCOMING_SSH_DISABLED"
    "encrypted-volumes"                        = "ENCRYPTED_VOLUMES"
    "ec2-imdsv2-check"                         = "EC2_IMDSV2_CHECK"
    "iam-password-policy"                      = "IAM_PASSWORD_POLICY"
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = var.enable_config ? local.managed_config_rules : {}
  name     = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
