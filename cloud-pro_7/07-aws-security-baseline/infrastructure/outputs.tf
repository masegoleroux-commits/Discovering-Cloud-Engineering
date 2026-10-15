output "trail_name" {
  value = aws_cloudtrail.main.name
}

output "trail_bucket" {
  value = aws_s3_bucket.trail.bucket
}

output "trail_log_group" {
  value = aws_cloudwatch_log_group.trail.name
}

output "config_rule_names" {
  value = keys(aws_config_config_rule.managed)
}
