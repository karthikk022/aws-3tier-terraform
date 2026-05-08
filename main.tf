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
  ami_id            = var.ami_id
  key_name          = var.key_name
  min_size          = var.web_min_size
  max_size          = var.web_max_size
  desired_capacity  = var.web_desired_capacity
  health_check_path = "/"
  app_port          = 80
}

module "app" {
  source = "./modules/app"

  vpc_id           = module.vpc.vpc_id
  app_subnet_ids   = module.vpc.app_subnet_ids
  web_sg_id        = module.web.sg_id
  environment      = var.environment
  project_name     = var.project_name
  instance_type    = var.app_instance_type
  ami_id           = var.ami_id
  key_name         = var.key_name
  min_size         = var.app_min_size
  max_size         = var.app_max_size
  desired_capacity = var.app_desired_capacity
  app_port         = 3000
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
  skip_final_snapshot = var.skip_final_snapshot
  multi_az            = var.environment == "prod" ? true : false
}
