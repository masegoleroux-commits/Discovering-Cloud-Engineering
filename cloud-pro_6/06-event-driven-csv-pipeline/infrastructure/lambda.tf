data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

locals {
  lambdas = {
    validate = {
      source_dir = "${path.module}/../src/validate"
      env = {
        MAX_FILE_BYTES = tostring(var.max_file_bytes)
        MAX_ROWS       = tostring(var.max_rows)
      }
    }
    load = {
      source_dir = "${path.module}/../src/load"
      env        = { ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name }
    }
  }
}

data "archive_file" "lambda" {
  for_each    = local.lambdas
  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each          = local.lambdas
  name              = "/aws/lambda/${local.name_prefix}-${each.key}"
  retention_in_days = 1
}

# Separate roles: the validator can't write to the database even if its code is compromised.
resource "aws_iam_role" "lambda" {
  for_each           = local.lambdas
  name               = "${local.name_prefix}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_logs" {
  for_each = local.lambdas
  name     = "${local.name_prefix}-${each.key}-logs"
  role     = aws_iam_role.lambda[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.lambda[each.key].arn}:*"
    }]
  })
}

resource "aws_iam_role_policy" "validate_read" {
  name = "${local.name_prefix}-validate-read"
  role = aws_iam_role.lambda["validate"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.uploads.arn}/${var.upload_prefix}*"
    }]
  })
}

resource "aws_iam_role_policy" "load_read_write" {
  name = "${local.name_prefix}-load-read-write"
  role = aws_iam_role.lambda["load"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.uploads.arn}/${var.upload_prefix}*" },
      { Effect = "Allow", Action = ["dynamodb:BatchWriteItem", "dynamodb:PutItem"], Resource = aws_dynamodb_table.orders.arn },
    ]
  })
}

resource "aws_lambda_function" "fn" {
  for_each         = local.lambdas
  function_name    = "${local.name_prefix}-${each.key}"
  role             = aws_iam_role.lambda[each.key].arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = data.archive_file.lambda[each.key].output_path
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb

  environment {
    variables = each.value.env
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda_logs]
}
