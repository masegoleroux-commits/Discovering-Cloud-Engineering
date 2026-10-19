resource "aws_sns_topic" "security_alerts" {
  name = "${local.name_prefix}-security-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  security_metric_filters = {
    "root-account-usage" = {
      metric_name = "RootAccountUsageCount"
      pattern     = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
    }
    "unauthorized-api-calls" = {
      metric_name = "UnauthorizedApiCallCount"
      pattern     = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
    }
    "security-group-changes" = {
      metric_name = "SecurityGroupChangeCount"
      pattern     = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
    }
    "console-login-without-mfa" = {
      metric_name = "ConsoleLoginWithoutMfaCount"
      pattern     = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type = \"IAMUser\") && ($.responseElements.ConsoleLogin = \"Success\") }"
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "security" {
  for_each       = local.security_metric_filters
  name           = "${local.name_prefix}-${each.key}"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = "SecurityBaseline"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "security" {
  for_each            = local.security_metric_filters
  alarm_name          = "${local.name_prefix}-${each.key}-alarm"
  alarm_description   = "One or more ${each.key} events in the last ${var.alarm_period_seconds} seconds"
  namespace           = "SecurityBaseline"
  metric_name         = each.value.metric_name
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.security]
}
