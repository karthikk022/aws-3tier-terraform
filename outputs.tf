output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs of the application private subnets"
  value       = module.vpc.app_subnet_ids
}

output "db_subnet_ids" {
  description = "IDs of the database private subnets"
  value       = module.vpc.db_subnet_ids
}

output "web_alb_dns_name" {
  description = "DNS name of the web ALB"
  value       = module.web.alb_dns_name
}

output "web_alb_zone_id" {
  description = "Route 53 zone ID of the web ALB"
  value       = module.web.alb_zone_id
}

output "app_internal_alb_dns_name" {
  description = "DNS name of the internal app ALB"
  value       = module.app.internal_alb_dns_name
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_address" {
  description = "RDS instance address"
  value       = module.database.db_address
  sensitive   = true
}

output "db_port" {
  description = "RDS instance port"
  value       = module.database.db_port
}
