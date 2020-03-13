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

resource "null_resource" "lambda_preconditions" {
  triggers {
    always_run = "${uuid()}"
  }
  provisioner "local-exec" {
    command = "rm -rf ${path.module}/../../target_lambda"
  }
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/../../target_lambda"
  }
  provisioner "local-exec" {
    command = "pip3 install --target=${path.module}/../../target_lambda requests"
  }
  provisioner "local-exec" {
    command = "cp -R ${path.module}/../../lambda_*.py ${path.module}/../../target_lambda/."
  }
  provisioner "local-exec" {
    command = "cd ${path.module}/../../target_lambda && zip -r lambda.zip ."
  }
}


data "archive_file" "zipit" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/monitoring_lambda.zip"
}

resource "aws_lambda_function" "monitoring_get_lambda" {
  function_name    = "monitoring_get_lambda"
  handler          = "hello_lambda.get_handler"
  role             = aws_iam_role.iam_role_for_lambda.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.zipit.output_base64sha256
  filename         = data.archive_file.zipit.output_path
  depends_on       = [null_resource.lambda_preconditions]

}


resource "aws_lambda_function" "monitoring_post_lambda" {
  function_name    = "monitoring_post_lambda"
  handler          = "hello_lambda.post_handler"
  role             = aws_iam_role.iam_role_for_lambda.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.zipit.output_base64sha256
  filename         = data.archive_file.zipit.output_path

}

# Now, we need an API to expose those functions publicly
resource "aws_api_gateway_rest_api" "portal_api" {
  name = "Portal API"
}

# The API requires at least one "endpoint", or "resource" in AWS terminology.
# The endpoint created here is: /hello

resource "aws_api_gateway_resource" "monitoring_api_res" {
  parent_id   = aws_api_gateway_rest_api.portal_api.root_resource_id
  path_part   = "monitoring"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
}

module "monitoring_get" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.monitoring_api_res.id
  method      = "GET"
  path        = aws_api_gateway_resource.monitoring_api_res.path
  lambda      = aws_lambda_function.monitoring_get_lambda.id
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
  lambda      = aws_lambda_function.monitoring_post_lambda.id
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# We can deploy the API now! (i.e. make it publicly available)
resource "aws_api_gateway_deployment" "hello_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  stage_name  = "production"
  description = "Deploy methods: ${module.monitoring_get.http_method} ${module.monitoring_post.http_method}"
}

resource "aws_api_gateway_usage_plan" "hello_api_plan" {
  name = "my_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.portal_api.id
    stage  = aws_api_gateway_deployment.hello_api_deployment.stage_name
  }
}

resource "aws_api_gateway_api_key" "hello_api_key" {
  name = "portal_key"
}

resource "aws_api_gateway_usage_plan_key" "hello_api_plan_key" {
  key_id        = aws_api_gateway_api_key.hello_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.hello_api_plan.id
}

