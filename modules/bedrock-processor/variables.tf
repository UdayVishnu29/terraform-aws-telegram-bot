variable "project_name" {
  description = "A unique name for the project to prefix resources."
  type        = string
}

variable "aws_region_secondary" {
  description = "The AWS region for the bot logic."
  type        = string
}

variable "telegram_bot_token" {
  description = "The secret token for your Telegram bot from BotFather."
  type        = string
  sensitive   = true
}

variable "bedrock_model_id" {
  description = "The model ID for the Amazon Bedrock model to use."
  type        = string
}