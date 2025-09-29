module "processor" {
  source = "./modules/bedrock-processor"

  # Pass variables to the processor module
  # Each provider is passed implicitly to the module based on its configuration
  project_name         = var.project_name
  aws_region_secondary = var.aws_region_secondary
  telegram_bot_token   = var.telegram_bot_token
  bedrock_model_id     = var.bedrock_model_id
}

module "webhook_endpoint" {
  source = "./modules/telegram-webhook"
  
  # Pass variables to the webhook module
  project_name       = var.project_name
  aws_region_primary = var.aws_region_primary
  
  # This is the crucial link:
  # Use the outputs from the "processor" module as inputs for this one.
  sqs_queue_arn      = module.processor.sqs_queue_arn
  sqs_queue_url      = module.processor.sqs_queue_url
}
