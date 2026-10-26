data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  trust_my_account = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Manages the key (rotation, aliases, scheduling deletion) but must never read data.
resource "aws_iam_role" "key_admin" {
  name               = "${local.name_prefix}-key-admin"
  description        = "Manages the KMS key; has no permission to use it"
  assume_role_policy = local.trust_my_account
}

# The application: uses the key through S3, DynamoDB and SQS.
resource "aws_iam_role" "app" {
  name               = "${local.name_prefix}-app"
  description        = "Reads and writes encrypted data"
  assume_role_policy = local.trust_my_account
}

# IAM deliberately lets the key admin READ the S3 object. If the read still fails,
# that proves the KMS key policy (not IAM or S3) is what protects the data.
resource "aws_iam_role_policy" "key_admin" {
  name = "${local.name_prefix}-key-admin"
  role = aws_iam_role.key_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadObjectsDeliberately"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
      },
      {
        Sid      = "SeeTheKey"
        Effect   = "Allow"
        Action   = ["kms:ListAliases", "kms:ListKeys"]
        Resource = "*" # list actions have no resource
      },
    ]
  })
}

resource "aws_iam_role_policy" "app" {
  name = "${local.name_prefix}-app"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Objects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
      },
      {
        Sid      = "Table"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.records.arn
      },
      {
        Sid      = "Queue"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage"]
        Resource = aws_sqs_queue.events.arn
      },
    ]
  })
}
