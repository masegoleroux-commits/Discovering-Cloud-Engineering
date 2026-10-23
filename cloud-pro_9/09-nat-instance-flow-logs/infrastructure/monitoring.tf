# ---- VPC Flow Logs: every accepted and rejected connection in the VPC ----
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/${local.name_prefix}/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${local.name_prefix}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

resource "aws_iam_role_policy" "flow" {
  name = "${local.name_prefix}-flow-logs-policy"
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow.arn
  iam_role_arn             = aws_iam_role.flow.arn
  max_aggregation_interval = 60 # 1-minute batches instead of 10, so you see results faster
  tags                     = { Name = "${local.name_prefix}-flow-log" }
}

# ---- Saved CloudWatch Logs Insights queries (appear under "Saved queries") ----
resource "aws_cloudwatch_query_definition" "rejected" {
  name            = "${local.name_prefix}/rejected-traffic"
  log_group_names = [aws_cloudwatch_log_group.flow.name]
  query_string    = <<-EOT
    fields @timestamp, srcAddr, dstAddr, dstPort, protocol, action
    | filter action = "REJECT"
    | stats count(*) as attempts by srcAddr, dstPort
    | sort attempts desc
    | limit 20
  EOT
}

resource "aws_cloudwatch_query_definition" "top_talkers" {
  name            = "${local.name_prefix}/top-talkers"
  log_group_names = [aws_cloudwatch_log_group.flow.name]
  query_string    = <<-EOT
    fields srcAddr, dstAddr, bytes
    | filter action = "ACCEPT"
    | stats sum(bytes) as totalBytes by srcAddr, dstAddr
    | sort totalBytes desc
    | limit 10
  EOT
}

resource "aws_cloudwatch_query_definition" "app_egress" {
  name            = "${local.name_prefix}/app-egress-via-nat"
  log_group_names = [aws_cloudwatch_log_group.flow.name]
  query_string    = <<-EOT
    fields @timestamp, srcAddr, dstAddr, dstPort, action
    | filter srcAddr = "${aws_instance.app.private_ip}"
    | sort @timestamp desc
    | limit 50
  EOT
}

# ---- NAT health: email, and let EC2 automatically recover the instance ----
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "nat_system_check" {
  alarm_name          = "${local.name_prefix}-nat-system-check-failed"
  alarm_description   = "NAT instance failed its system status check: EC2 recovers it onto healthy hardware"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  dimensions          = { InstanceId = aws_instance.nat.id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn, "arn:aws:automate:${var.aws_region}:ec2:recover"]
}
