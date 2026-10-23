output "nat_public_ip" {
  description = "Every outbound request from the private subnet should come from this address"
  value       = aws_eip.nat.public_ip
}

output "nat_instance_id" {
  value = aws_instance.nat.id
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "flow_log_group" {
  value = aws_cloudwatch_log_group.flow.name
}
