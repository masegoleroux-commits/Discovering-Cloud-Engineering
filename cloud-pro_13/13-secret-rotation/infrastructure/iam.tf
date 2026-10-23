locals {
  account_id = data.aws_caller_identity.current.account_id
  api_arn    = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.name_prefix}-api"

  # One least-privilege policy per function. Built with jsonencode so the tests can read it.
  fn_policies = {
    rotation = [
      {
        Sid      = "RotateThisSecretOnly"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage"]
        Resource = aws_secretsmanager_secret.api_key.arn
      },
      {
        Sid      = "GenerateKeys"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = "*" # this action has no resource; AWS requires "*"
      },
      {
        Sid      = "ManageRegistry"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.registry.arn
      },
      {
        Sid      = "TestNewKey"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = local.api_arn
      },
    ]
    api = [
      {
        Sid      = "CheckKeys"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = aws_dynamodb_table.registry.arn
      },
    ]
    client = [
      {
        Sid      = "ReadTheKeyOnly"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.api_key.arn
      },
      {
        Sid      = "CallTheApi"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = local.api_arn
      },
    ]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "fn" {
  for_each = local.functions
  name     = "${local.name_prefix}-${each.key}-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "fn" {
  for_each = local.functions
  name     = "${local.name_prefix}-${each.key}-access"
  role     = aws_iam_role.fn[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.fn_policies[each.key], [{
      Sid      = "OwnLogsOnly"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.fn[each.key].arn}:*"
    }])
  })
}
