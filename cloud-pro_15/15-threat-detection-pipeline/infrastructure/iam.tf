data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  fn_policies = {
    formatter = [{
      Sid      = "PublishAlerts"
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.alerts.arn
    }]
    # Tagging only, only security groups, and only the SecurityFinding tag:
    # it can't remove the risky rule, stop, change or delete anything (ADR 0001).
    responder = [{
      Sid       = "TagSecurityGroupsOnly"
      Effect    = "Allow"
      Action    = ["ec2:CreateTags"]
      Resource  = "arn:aws:ec2:${var.aws_region}:${local.account_id}:security-group/*"
      Condition = { "ForAllValues:StringEquals" = { "aws:TagKeys" = ["SecurityFinding"] } }
    }]
  }
}

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
