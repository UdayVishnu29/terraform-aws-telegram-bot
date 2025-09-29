output "api_gateway_invoke_url" {
  description = "The invocation URL for the API Gateway webhook."
  value       = aws_apigatewayv2_api.telegram_api.api_endpoint
}
