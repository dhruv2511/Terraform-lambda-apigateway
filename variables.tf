variable "aws_region" {
  description = "AWS region"
  default     = "ap-southeast-2"
}

variable "runtime" {
  description = "Run Time for the code"
  default     = "python3.7"
}

variable "access_token" {
  description = "Access Token for TF API"
  default     = ""
}

variable "dynamodb_table" {
  description = "DynamoDb Table Name that creates the database"
  default     = "test"
}