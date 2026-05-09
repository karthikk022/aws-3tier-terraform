variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "app_subnet_ids" {
  description = "List of application private subnet IDs"
  type        = list(string)
}

variable "web_sg_id" {
  description = "Security group ID of the web tier"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for app server instances"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum size of the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum size of the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired capacity of the ASG"
  type        = number
  default     = 1
}

variable "app_port" {
  description = "Port the application server listens on"
  type        = number
  default     = 3000
}

variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
