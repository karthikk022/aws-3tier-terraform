variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
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
  description = "AMI ID for web server instances"
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
  default     = 2
}

variable "health_check_interval" {
  description = "Health check interval for the ALB target group"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Health check path for the ALB target group"
  type        = string
  default     = "/"
}

variable "app_port" {
  description = "Port the web server listens on"
  type        = number
  default     = 80
}

variable "app_alb_dns" {
  description = "DNS name of the application load balancer"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
  default     = ""
}
