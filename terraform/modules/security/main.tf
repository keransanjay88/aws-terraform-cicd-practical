resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-alb-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2-sg"
  description = "Application EC2 instances"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-ec2-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS MySQL database"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-rds-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- ALB rules ----------------
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_redirect" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet (only used to redirect to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to app instances only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.ec2.id
}

# ---------------- EC2 rules ----------------
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "App traffic from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ec2_https_out" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS out via NAT/S3 endpoint (SSM, Secrets Manager, S3, package repos)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "MySQL to the database only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.rds.id
}

# ---------------- RDS rules ----------------
resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from app instances only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.ec2.id
}

# No egress rules on the RDS group: the database never initiates connections.