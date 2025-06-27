variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project, used for tagging resources."
  type        = string
  default     = "task-manager-app"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_username" {
  description = "Username for the RDS database."
  type        = string
  sensitive   = true
  default     = "adminuser" # In a real project, use a secret manager
}

variable "db_password" {
  description = "Password for the RDS database."
  type        = string
  sensitive   = true
  default     = "Password12345" # In a real project, use a secret manager
}


variable "domain_name" {
  description = "The registered domain name for the application"
  type        = string
  default     = "my-task-app.com"
}