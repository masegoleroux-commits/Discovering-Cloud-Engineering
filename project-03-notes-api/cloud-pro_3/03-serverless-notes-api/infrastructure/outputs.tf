output "api_base_url" {
  description = "Base URL for curl and the smoke test"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "table_name" {
  value = aws_dynamodb_table.notes.name
}

output "function_name" {
  value = aws_lambda_function.handler.function_name
}
