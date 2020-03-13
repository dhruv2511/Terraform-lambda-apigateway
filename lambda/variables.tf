variable "name" {
  description = "The name of the lambda to create, which also defines (i) the archive name (.zip), (ii) the file name, and (iii) the function name"
}

variable "runtime" {
  description = "The runtime of the lambda to create"
  default     = "nodejs"
}

variable "handler" {
  description = "The handler name of the lambda (a function defined in your lambda)"
  default     = "handler"
}

variable "role" {
  description = "IAM role attached to the Lambda Function (ARN)"
}

variable "description" {
  description = "Description for the lambda"
}

variable "filename" {
  description = "File name for where the lambda is located"
}

variable "source_code" {
  description = "Source Code hash to be used for the lambda"
}

variable "env_variables" {
  description = "Environmental variables for the lambda"
  default     = {}
}