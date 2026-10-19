output "peering_connection_ids" {
  value = { for k, v in aws_vpc_peering_connection.this : k => v.id }
}

output "vpc_ids" {
  value = { for k, v in aws_vpc.this : k => v.id }
}

output "path_app_to_shared" {
  value = aws_ec2_network_insights_path.test["app-to-shared"].id
}

output "path_data_to_shared" {
  value = aws_ec2_network_insights_path.test["data-to-shared"].id
}

output "path_app_to_data" {
  value = aws_ec2_network_insights_path.test["app-to-data"].id
}

output "allow_app_to_data" {
  value = var.allow_app_to_data
}
