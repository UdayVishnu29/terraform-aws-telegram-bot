output "api_gateway_invoke_url" {
  description = "The invocation URL for the API Gateway webhook."
  value       = module.webhook_endpoint.api_gateway_invoke_url
}

output "set_webhook_command" {
  description = "The curl command to set the Telegram webhook."
  value       = "curl -s -X POST \"https://api.telegram.org/bot${var.telegram_bot_token}/setWebhook\" -H \"Content-Type: application/json\" -d '{\"url\":\"${module.webhook_endpoint.api_gateway_invoke_url}\",\"secret_token\":\"${var.telegram_secret_token}\"}'"
  sensitive   = true
}