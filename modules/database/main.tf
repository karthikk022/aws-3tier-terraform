resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for database tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "db"
  }
}

resource "aws_db_subnet_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Database subnet group for ${var.project_name}-${var.environment}"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "random_id" "snapshot" {
  count       = var.skip_final_snapshot ? 0 : 1
  byte_length = 4
}

resource "aws_db_instance" "db" {
  identifier = "${var.project_name}-${var.environment}-rds"

  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az                = var.multi_az
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-${random_id.snapshot[0].hex}"

  auto_minor_version_upgrade = true
  deletion_protection        = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "db"
  }
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.db.endpoint
}

output "db_address" {
  description = "RDS instance address"
  value       = aws_db_instance.db.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.db.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.db.db_name
}

output "sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.db.id
}
