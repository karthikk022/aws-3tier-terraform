data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  environment        = var.environment
  project_name       = var.project_name

  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
}

module "web" {
  source = "./modules/web"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  environment       = var.environment
  project_name      = var.project_name
  instance_type     = var.web_instance_type
  ami_id            = local.ami_id
  key_name          = var.key_name
  min_size          = var.web_min_size
  max_size          = var.web_max_size
  desired_capacity  = var.web_desired_capacity
  health_check_path = "/"
  app_port          = 80
  app_alb_dns       = module.app.internal_alb_dns_name
}

module "app" {
  source = "./modules/app"

  vpc_id           = module.vpc.vpc_id
  app_subnet_ids   = module.vpc.app_subnet_ids
  web_sg_id        = module.web.sg_id
  environment      = var.environment
  project_name     = var.project_name
  instance_type    = var.app_instance_type
  ami_id           = local.ami_id
  key_name         = var.key_name
  min_size         = var.app_min_size
  max_size         = var.app_max_size
  desired_capacity = var.app_desired_capacity
  app_port         = 3000
  db_endpoint      = module.database.db_endpoint
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-${var.environment}-terraform-state"

  tags = {
    Name        = "${var.project_name}-${var.environment}-terraform-state"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-${var.environment}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-terraform-locks"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Secrets Manager for Database Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-${var.environment}-db-credentials"
  description = "Database credentials for ${var.project_name}"
  
  recovery_window_in_days = 0 # For development/demo purposes
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = var.db_engine
    host     = module.database.db_address
    port     = var.db_port
    db_name  = var.db_name
  })
}

module "database" {
  source = "./modules/database"

  vpc_id              = module.vpc.vpc_id
  db_subnet_ids       = module.vpc.db_subnet_ids
  app_sg_id           = module.app.sg_id
  environment         = var.environment
  project_name        = var.project_name
  db_username         = var.db_username
  db_password         = var.db_password
  db_name             = var.db_name
  engine              = var.db_engine
  engine_version      = var.db_engine_version
  instance_class      = var.db_instance_class
  db_port             = var.db_port
  skip_final_snapshot = var.skip_final_snapshot
  multi_az            = var.environment == "prod" ? true : false
}
