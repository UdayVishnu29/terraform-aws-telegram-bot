# SQS Queue to decouple the Lambdas
resource "aws_sqs_queue" "telegram_queue" {
  name = "${var.project_name}-queue"
}

# DynamoDB Table for chat history
resource "aws_dynamodb_table" "chat_history" {
  name         = "${var.project_name}-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "chat_id"

  attribute {
    name = "chat_id"
    type = "N"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# IAM Role for the second Lambda (the bot processor)
resource "aws_iam_role" "processor_lambda_role" {
  name               = "${var.project_name}-processor-role-${var.aws_region_secondary}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM Policy for the processor Lambda
resource "aws_iam_policy" "processor_lambda_policy" {
  name   = "${var.project_name}-processor-policy-${var.aws_region_secondary}"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "bedrock:InvokeModel",
        Resource = "arn:aws:bedrock:${var.aws_region_secondary}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Effect   = "Allow",
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"],
        Resource = aws_dynamodb_table.chat_history.arn
      },
      {
        Effect   = "Allow",
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.telegram_queue.arn
      }
    ]
  })
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "processor_lambda_basic" {
  role       = aws_iam_role.processor_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "processor_lambda_custom" {
  role       = aws_iam_role.processor_lambda_role.name
  policy_arn = aws_iam_policy.processor_lambda_policy.arn
}

# Zip the code for the processor Lambda
data "archive_file" "processor_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-code" # Assumes code is in modules/bedrock-processor/lambda-code
  output_path = "${path.module}/lambda-code.zip"
}

# The second Lambda function (the bot processor)
resource "aws_lambda_function" "processor_lambda" {
  function_name    = "${var.project_name}-processor"
  role             = aws_iam_role.processor_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.processor_lambda_code.output_path
  source_code_hash = data.archive_file.processor_lambda_code.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN   = var.telegram_bot_token
      BEDROCK_MODEL_ID     = var.bedrock_model_id
      DYNAMODB_TABLE_NAME  = aws_dynamodb_table.chat_history.name
    }
  }
}

# SQS trigger for the processor Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.telegram_queue.arn
  function_name    = aws_lambda_function.processor_lambda.arn
  batch_size       = 1
}
