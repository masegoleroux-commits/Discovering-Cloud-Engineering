output "instance_id" {
  value = aws_instance.workload.id
}

output "data_bucket" {
  value = aws_s3_bucket.data.bucket
}

output "outside_bucket" {
  value = aws_s3_bucket.outside.bucket
}

output "events_table" {
  value = aws_dynamodb_table.events.name
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  value = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}
