resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-pipeline"
  retention_in_days = 1
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "state_machine" {
  name               = "${local.name_prefix}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

resource "aws_iam_role_policy" "state_machine" {
  name = "${local.name_prefix}-sfn-policy"
  role = aws_iam_role.state_machine.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [for f in aws_lambda_function.fn : f.arn] },
      { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.dead_letter.arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notifications.arn },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies", "logs:DescribeLogGroups",
        ]
        Resource = "*" # these log-delivery APIs don't support resource-level permissions
      },
    ]
  })
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.state_machine.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/templates/pipeline.asl.json.tftpl", {
    validate_function_arn = aws_lambda_function.fn["validate"].arn
    load_function_arn     = aws_lambda_function.fn["load"].arn
    topic_arn             = aws_sns_topic.notifications.arn
    dead_letter_queue_url = aws_sqs_queue.dead_letter.url
    task_max_attempts     = var.task_max_attempts
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  depends_on = [aws_iam_role_policy.state_machine]
}
