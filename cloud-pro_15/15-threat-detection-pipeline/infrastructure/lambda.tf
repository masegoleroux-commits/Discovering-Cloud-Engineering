locals {
  functions = {
    formatter = "Turns risky CloudTrail events into readable email alerts"
    responder = "Tags a security group opened to the internet; never removes rules or deletes anything"
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
  description      = each.value
  role             = aws_iam_role.fn[each.key].arn
  runtime          = "python3.12"
  handler          = "app.lambda_handler"
  filename         = data.archive_file.fn[each.key].output_path
  source_code_hash = data.archive_file.fn[each.key].output_base64sha256
  timeout          = 15
  memory_size      = 128

  environment {
    variables = {
      TOPIC_ARN  = aws_sns_topic.alerts.arn
      TEST_SG_ID = aws_security_group.canary.id # alerts about this group are labelled DELIBERATE TEST
      LOG_LEVEL  = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.fn, aws_iam_role_policy.fn]
}
