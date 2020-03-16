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
####################################################################################
# Lambda Monitoring and Logging
####################################################################################


# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_role_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}


data "archive_file" "zipit" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/monitoring_lambda.zip"
}

resource "aws_lambda_function" "status_tfe_lambda" {
  function_name    = "monitoring_get_lambda"
  handler          = "tfe_status.tfe_status_handler"
  role             = aws_iam_role.iam_role_for_lambda.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.zipit.output_base64sha256
  filename         = data.archive_file.zipit.output_path
  environment {
    variables = {
      access_token = var.access_token
    }
  }

}


resource "aws_lambda_function" "status_dynamodb_lambda" {
  function_name    = "monitoring_post_lambda"
  handler          = "dynamodb_status.handler"
  role             = aws_iam_role.iam_role_for_lambda.arn
  runtime          = "python3.7"
  source_code_hash = data.archive_file.zipit.output_base64sha256
  filename         = data.archive_file.zipit.output_path
  environment {
    variables = {
      access_token = var.access_token
    }
  }
}

###############################################################################
# Logging and Monitoring the API
###############################################################################
resource "aws_api_gateway_account" "portal" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "default"
  role = aws_iam_role.cloudwatch.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_method_settings" "get_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  stage_name  = aws_api_gateway_deployment.hello_api_deployment.stage_name
  method_path = "${aws_api_gateway_resource.monitoring_api_res.path_part}/${module.status_tfe.http_method}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}
# Now, we need an API to expose those functions publicly
resource "aws_api_gateway_rest_api" "portal_api" {
  name = "Portal API"
}

# The API requires at least one "endpoint", or "resource" in AWS terminology.
# The endpoint created here is: /hello

resource "aws_api_gateway_resource" "status_tfe_api_rest" {
  parent_id   = aws_api_gateway_rest_api.portal_api.root_resource_id
  path_part   = "terraform"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
}


resource "aws_api_gateway_resource" "status_dynamodb_api_rest" {
  parent_id   = aws_api_gateway_rest_api.portal_api.root_resource_id
  path_part   = "dynamodb"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
}

module "status_tfe" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.status_tfe_api_rest.id
  method      = "GET"
  path        = aws_api_gateway_resource.status_tfe_api_rest.path
  lambda      = aws_lambda_function.status_tfe_lambda.id
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# This is the code for method POST /data, that will talk to the second lambda
module "status_dynamoDB" {
  source      = "./api_method"
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  resource_id = aws_api_gateway_resource.status_dynamodb_api_rest.id
  method      = "GET"
  path        = aws_api_gateway_resource.status_dynamodb_api_rest.path
  lambda      = aws_lambda_function.status_dynamodb_lambda.id
  region      = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
}

# We can deploy the API now! (i.e. make it publicly available)
resource "aws_api_gateway_deployment" "hello_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.portal_api.id
  stage_name  = "production"
  description = "Deploy methods: ${module.status_tfe.http_method} ${module.status_dynamoDB.http_method}"
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

