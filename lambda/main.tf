resource "aws_lambda_function" "lambda" {
  function_name    = "${var.name}_${var.handler}"
  description      = var.description
  role             = var.role
  runtime          = var.runtime
  handler          = var.handler
  filename         = var.filename
  source_code_hash = var.source_code
  environment = {
    variables = var.env_variables
  }
}