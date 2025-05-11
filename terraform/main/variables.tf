variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "app_name" {
  description = "Name of the banking application"
  type        = string
  default     = "banking-app"
}
