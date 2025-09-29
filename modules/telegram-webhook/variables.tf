variable "project_name" {
  description = "A unique name for the project to prefix resources."
  type        = string
}

variable "sqs_queue_arn" {
  description = "The ARN of the SQS queue to send messages to."
  type        = string
}

variable "sqs_queue_url" {
  description = "The URL of the SQS queue to send messages to."
  type        = string
}

variable "aws_region_primary" {
  description = "The AWS region for the webhook."
  type        = string
}