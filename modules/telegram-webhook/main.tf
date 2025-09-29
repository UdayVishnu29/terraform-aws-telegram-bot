# Provider block is not needed here as it's inherited from the root module call

# IAM Role for the first Lambda (the webhook receiver)
resource "aws_iam_role" "receiver_lambda_role" {
  name               = "${var.project_name}-receiver-role-${var.aws_region_primary}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM Policy for the receiver Lambda
resource "aws_iam_policy" "receiver_lambda_policy" {
  name   = "${var.project_name}-receiver-policy-${var.aws_region_primary}"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sqs:SendMessage",
      Resource = var.sqs_queue_arn # Input variable
    }]
  })
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "receiver_lambda_basic" {
  role       = aws_iam_role.receiver_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "receiver_lambda_custom" {
  role       = aws_iam_role.receiver_lambda_role.name
  policy_arn = aws_iam_policy.receiver_lambda_policy.arn
}

# Zip the code for the receiver Lambda
data "archive_file" "receiver_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-code" # Assumes code is in modules/telegram-webhook/lambda-code
  output_path = "${path.module}/lambda-code.zip"
}

# The first Lambda function (the webhook receiver)
resource "aws_lambda_function" "receiver_lambda" {
  function_name    = "${var.project_name}-receiver"
  role             = aws_iam_role.receiver_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.receiver_lambda_code.output_path
  source_code_hash = data.archive_file.receiver_lambda_code.output_base64sha256

  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_queue_url # Input variable
    }
  }
}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "telegram_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  target        = aws_lambda_function.receiver_lambda.invoke_arn
}

# Lambda permission to allow API Gateway invocation
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receiver_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.telegram_api.execution_arn}/*/*"
}