output "topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "formatter_log_group" {
  value = aws_cloudwatch_log_group.fn["formatter"].name
}

output "responder_log_group" {
  value = aws_cloudwatch_log_group.fn["responder"].name
}

output "rule_names" {
  value = [for r in aws_cloudwatch_event_rule.detect : r.name]
}

output "trail_name" {
  description = "The trail this project created (empty when create_trail = false)"
  value       = var.create_trail ? aws_cloudtrail.main[0].name : ""
}

output "test_security_group_id" {
  description = "The harmless security group the deliberate test opens and closes"
  value       = aws_security_group.canary.id
}
