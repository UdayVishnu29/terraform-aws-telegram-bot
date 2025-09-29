variable "project_name" {
  description = "A unique name for the project to prefix resources."
  type        = string
  default     = "telegram-bedrock-bot"
}

variable "aws_region_primary" {
  description = "The primary AWS region for the webhook (API Gateway, Lambda #1)."
  type        = string
  default     = "eu-north-1"
}

variable "aws_region_secondary" {
  description = "The secondary AWS region for the bot logic (SQS, Lambda #2, Bedrock)."
  type        = string
  default     = "us-east-1"
}

variable "telegram_bot_token" {
  description = "The secret token for your Telegram bot from BotFather."
  type        = string
  sensitive   = true
}

variable "telegram_secret_token" {
  description = "A secret token used to validate webhook calls from Telegram."
  type        = string
  sensitive   = true
}

variable "bedrock_model_id" {
  description = "The model ID for the Amazon Bedrock model to use."
  type        = string
  default     = "amazon.titan-text-lite-v1"
}