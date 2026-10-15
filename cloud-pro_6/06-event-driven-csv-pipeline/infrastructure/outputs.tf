output "upload_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}

output "dead_letter_queue_url" {
  value = aws_sqs_queue.dead_letter.url
}

output "orders_table" {
  value = aws_dynamodb_table.orders.name
}
