output "client_instance_id" {
  value = aws_instance.client.id
}

output "private_zone" {
  value = aws_route53_zone.private.name
}

output "service_ips" {
  value = { for k, v in aws_network_interface.service : k => v.private_ip }
}

output "query_log_group" {
  value = aws_cloudwatch_log_group.queries.name
}
