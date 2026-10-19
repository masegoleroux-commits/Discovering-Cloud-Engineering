# On-demand billing: pay per request, no throttling at low capacity.
resource "aws_dynamodb_table" "orders" {
  name         = "${local.name_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

resource "aws_sqs_queue" "dead_letter" {
  name                      = "${local.name_prefix}-failed"
  message_retention_seconds = 86400
  sqs_managed_sse_enabled   = true
}

resource "aws_sns_topic" "notifications" {
  name = "${local.name_prefix}-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
