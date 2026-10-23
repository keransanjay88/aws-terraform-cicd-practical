# Subnet group: tells RDS to use only the private DB subnets
resource "aws_db_subnet_group" "this" {
  name        = "${var.project}-db-subnets"
  description = "Private DB subnets"
  subnet_ids  = var.db_subnet_ids

  tags = { Name = "${var.project}-db-subnets" }
}

# Parameter group: force TLS connections and use utf8mb4
resource "aws_db_parameter_group" "this" {
  name        = "${var.project}-mysql-params"
  family      = var.parameter_group_family
  description = "MySQL parameters for ${var.project}"

  parameter {
    name  = "require_secure_transport"
    value = "1"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  tags = { Name = "${var.project}-mysql-params" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.project}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true # free AWS-managed key (aws/rds)

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  publicly_accessible = false
  multi_az            = var.multi_az
  port                = 3306

  # Automated backups. 1 day is the most free-tier accounts allow.
  backup_retention_period = 1
  backup_window           = "20:00-21:00"
  maintenance_window      = "sun:21:30-sun:22:30"

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  performance_insights_enabled    = false
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true

  # Demo settings: easy teardown (production would flip these)
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "${var.project}-mysql" }
}