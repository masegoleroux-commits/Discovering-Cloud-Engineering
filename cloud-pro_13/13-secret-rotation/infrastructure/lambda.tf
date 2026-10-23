locals {
  functions = {
    rotation = { description = "Rotates the partner API key in four steps", timeout = 30 }
    api      = { description = "Demo partner API: accepts only registered keys", timeout = 10 }
    client   = { description = "Demo client app: reads the key (cached) and calls the API", timeout = 15 }
  }
}

data "archive_file" "fn" {
  for_each    = local.functions
  type        = "zip"
  source_file = "${path.module}/../src/${each.key}/app.py"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_cloudwatch_log_group" "fn" {
  for_each          = local.functions
  name              = "/aws/lambda/${local.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "fn" {
  for_each         = local.functions
  function_name    = "${local.name_prefix}-${each.key}"
  description      = each.value.description
  role             = aws_iam_role.fn[each.key].arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = data.archive_file.fn[each.key].output_path
  source_code_hash = data.archive_file.fn[each.key].output_base64sha256
  timeout          = each.value.timeout
  memory_size      = 128

  environment {
    variables = {
      REGISTRY_TABLE = aws_dynamodb_table.registry.name
      API_FUNCTION   = "${local.name_prefix}-api"
      SECRET_ID      = aws_secretsmanager_secret.api_key.arn
      CACHE_SECONDS  = tostring(var.client_cache_seconds)
      LOG_LEVEL      = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.fn, aws_iam_role_policy.fn]
}

# Only Secrets Manager, and only for this one secret, may run the rotation function.
resource "aws_lambda_permission" "secretsmanager" {
  statement_id  = "AllowSecretsManagerRotation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn["rotation"].function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.api_key.arn
}
