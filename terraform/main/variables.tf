variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "artifact_bucket" {
  type = string
}


variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.100.20.0/24", "10.100.21.0/24", "10.100.22.0/24"]
}

variable "app_name" {
  description = "Name of the banking application"
  type        = string
  default     = "banking-app"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "bankingdb"
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "admin"
}

# Password is now managed by Secrets Manager
# variable "db_password" {
#   description = "Password for the database"
#   type        = string
#   default     = "YourStrongPasswordHere123!" # In production, use AWS Secrets Manager or similar
# }

variable "db_instance_class" {
  description = "Instance class for the RDS database"
  type        = string
  default     = "db.t3.micro"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "ami_owner" {
  description = "Owner of the AMI to use for EC2 instances"
  type        = string
  default     = "amazon"
}

variable "ami_name_pattern" {
  description = "Name pattern for the AMI to use for EC2 instances"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}