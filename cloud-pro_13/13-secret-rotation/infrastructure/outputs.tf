output "secret_arn" {
  value = aws_secretsmanager_secret.api_key.arn
}

output "registry_table" {
  value = aws_dynamodb_table.registry.name
}

output "client_function" {
  value = aws_lambda_function.fn["client"].function_name
}

output "api_function" {
  value = aws_lambda_function.fn["api"].function_name
}

output "rotation_function" {
  value = aws_lambda_function.fn["rotation"].function_name
}
