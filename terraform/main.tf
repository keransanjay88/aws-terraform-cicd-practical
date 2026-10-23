data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "network" {
  source = "./modules/network"

  project             = var.project
  vpc_cidr            = var.vpc_cidr
  azs                 = local.azs
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  app_subnet_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
  db_subnet_cidrs     = ["10.0.21.0/24", "10.0.22.0/24"]
  nat_count           = var.nat_count
}

module "security" {
  source = "./modules/security"

  project  = var.project
  vpc_id   = module.network.vpc_id
  app_port = var.app_port
}

data "aws_caller_identity" "current" {}

# Fixed names shared by several modules, so they always agree
locals {
  account_id         = data.aws_caller_identity.current.account_id
  secret_name        = "${var.project}/db-credentials"
  app_bucket_name    = "${var.project}-app-${local.account_id}"
  logs_bucket_name   = "${var.project}-alb-logs-${local.account_id}"
  secret_arn_pattern = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_name}-??????"
}

module "iam" {
  source = "./modules/iam"

  project            = var.project
  secret_arn_pattern = local.secret_arn_pattern
  app_bucket_arn     = "arn:aws:s3:::${local.app_bucket_name}"
}

module "secrets" {
  source = "./modules/secrets"

  secret_name = local.secret_name
}