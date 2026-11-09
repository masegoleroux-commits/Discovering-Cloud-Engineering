# ---------- What counts as "risky": three EventBridge rules on CloudTrail events ----------
# My account's organisation blocks GuardDuty and Security Hub (explicit SCP deny, see ADR 0003),
# so detection comes from CloudTrail: every API call in the account is an event, and these
# rules pick out the dangerous ones (ADR 0002 explains what is filtered where).
locals {
  detections = {
    # Any new inbound security-group rule. Whether it's open to the whole internet
    # (0.0.0.0/0 or ::/0) is decided in the Lambda code, which unit tests cover (ADR 0002).
    sg-open-to-internet = {
      description = "Inbound security group rule added (the functions alert only if it's open to the internet)"
      pattern = {
        source        = ["aws.ec2"]
        "detail-type" = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["ec2.amazonaws.com"]
          eventName   = ["AuthorizeSecurityGroupIngress"]
        }
      }
    }
    # Someone switching off the audit trail: the classic first move to hide what comes next
    audit-logging-stopped = {
      description = "CloudTrail logging was stopped or a trail was deleted"
      pattern = {
        source        = ["aws.cloudtrail"]
        "detail-type" = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["cloudtrail.amazonaws.com"]
          eventName   = ["StopLogging", "DeleteTrail"]
        }
      }
    }
    # The safety switch that stops buckets becoming public was removed
    s3-public-block-removed = {
      description = "An S3 bucket's Block Public Access settings were deleted"
      pattern = {
        source        = ["aws.s3"]
        "detail-type" = ["AWS API Call via CloudTrail"]
        detail = {
          eventSource = ["s3.amazonaws.com"]
          eventName   = ["DeleteBucketPublicAccessBlock"]
        }
      }
    }
  }

  # every rule sends its events to both functions
  targets = { for pair in setproduct(keys(local.detections), keys(local.functions)) : "${pair[0]}.${pair[1]}" => { rule = pair[0], fn = pair[1] } }
}

resource "aws_cloudwatch_event_rule" "detect" {
  for_each      = local.detections
  name          = "${local.name_prefix}-${each.key}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)
}

resource "aws_cloudwatch_event_target" "fn" {
  for_each = local.targets
  rule     = aws_cloudwatch_event_rule.detect[each.value.rule].name
  arn      = aws_lambda_function.fn[each.value.fn].arn
}

resource "aws_lambda_permission" "events" {
  for_each      = local.targets
  statement_id  = "AllowEventBridge-${each.value.rule}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn[each.value.fn].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.detect[each.value.rule].arn
}

# ---------- Alerts ----------
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- A harmless security group for the deliberate test ----------
# It sits in its own empty VPC and is attached to nothing, so opening it to the
# internet for a few minutes exposes nothing. run_tests.sh opens it, then closes it.
resource "aws_vpc" "canary" {
  cidr_block = "10.70.0.0/16"
  tags       = { Name = "${local.name_prefix}-canary-vpc" }
}

resource "aws_security_group" "canary" {
  name        = "${local.name_prefix}-canary-sg"
  description = "DELIBERATE TEST target: attached to nothing; run_tests.sh opens it briefly to trigger an alert"
  vpc_id      = aws_vpc.canary.id
  tags        = { Name = "${local.name_prefix}-canary-sg", Purpose = "deliberate-test" }

  lifecycle {
    ignore_changes = [tags, tags_all] # the responder adds a SecurityFinding tag during the test
  }
}
