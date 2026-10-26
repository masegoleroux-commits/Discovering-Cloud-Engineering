output "key_arn" {
  value = aws_kms_key.data.arn
}

output "key_alias" {
  value = aws_kms_alias.data.name
}

output "bucket" {
  value = aws_s3_bucket.data.bucket
}

output "table" {
  value = aws_dynamodb_table.records.name
}

output "queue_url" {
  value = aws_sqs_queue.events.url
}

output "key_admin_role_arn" {
  value = aws_iam_role.key_admin.arn
}

output "app_role_arn" {
  value = aws_iam_role.app.arn
}
