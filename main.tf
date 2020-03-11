provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# First, we need a role to play with Lambda
resource "aws_iam_role" "iam_role_for_lambda" {
  name = "iam_role_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Here is a first lambda function that will run the code `hello_lambda.handler`
data "archive_file" "api_lambda" {
  source_dir  = "${path.module}/lambdas"
  output_path = "${path.module}/lambdas.zip"
  type        = "zip"
}

module "lambda" {
  source      = "./lambda"
  description = "Get Handler for the api"
  filename    = data.archive_file.api_lambda.output_path
  source_code = data.archive_file.api_lambda.output_base64sha256
  name        = "hello_lambda"
  handler     = "get_handler"
  runtime     = var.runtime
  role        = aws_iam_role.iam_role_for_lambda.arn
}

# This is a second lambda function that will run the code
# `hello_lambda.post_handler`
module "lambda_post" {
  source      = "./lambda"
  description = "Post handler for the api"
  filename    = data.archive_file.api_lambda.output_path
  source_code = data.archive_file.api_lambda.output_base64sha256
  name        = "hello_lambda"
  handler     = "post_handler"
  runtime     = var.runtime
  role        = aws_iam_role.iam_role_for_lambda.arn
}

# Now, we need an API to expose those functions publicly
resource "aws_api_gateway_rest_api" "portal_api" {
  name = "Portal API"
}

# The API requires at least one "endpoint", or "resource" in AWS terminology.
# The endpoint created here is: /hello
resource "aws_api_gateway_resource" "data_api_res" {
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  parent_id   = aws_api_gateway_rest_api.portal_api.root_resource_id
  path_part   = "data"
}

resource "aws_api_gateway_resource" "monitoring_api_res" {
  parent_id   = aws_api_gateway_rest_api.portal_api.id
  path_part   = "monitoring"
  rest_api_id = aws_api_gateway_rest_api.portal_api.root_resource_id
}

# Until now, the resource created could not respond to anything. We must set up
# a HTTP method (or verb) for that!
# This is the code for method GET /daata, that will talk to the first lambda
module "data_get" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.data_api_res.id
  method      = "GET"
  path        = aws_api_gateway_resource.data_api_res.path
  lambda      = module.lambda.name
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# This is the code for method POST /data, that will talk to the second lambda
module "data_post" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.data_api_res.id
  method      = "POST"
  path        = aws_api_gateway_resource.data_api_res.path
  lambda      = module.lambda_post.name
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}


# Until now, the resource created could not respond to anything. We must set up
# a HTTP method (or verb) for that!
# This is the code for method GET /monitoring, that will talk to the first lambda
module "monitoring_get" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.monitoring_api_res.id
  method      = "GET"
  path        = aws_api_gateway_resource.monitoring_api_res.path
  lambda      = module.lambda.name
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# This is the code for method POST /data, that will talk to the second lambda
module "monitoring_post" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.monitoring_api_res.id
  method      = "POST"
  path        = aws_api_gateway_resource.monitoring_api_res.path
  lambda      = module.lambda_post.name
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# We can deploy the API now! (i.e. make it publicly available)
resource "aws_api_gateway_deployment" "hello_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  stage_name  = "production"
  description = "Deploy methods: ${module.data_get.http_method} ${module.data_post.http_method} ${module.monitoring_get.http_method} ${module.monitoring_post.http_method}"
}

