resource "aws_lambda_function" "lambda" {
  function_name    = var.name
  description      = var.description
  role             = var.role
  runtime          = var.runtime
  handler          = "${var.name}.${var.handler}"
  filename         = var.filename
  source_code_hash = var.source_code
}