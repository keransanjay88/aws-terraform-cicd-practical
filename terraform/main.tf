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

module "s3" {
  source = "./modules/s3"

  app_bucket_name  = local.app_bucket_name
  logs_bucket_name = local.logs_bucket_name
  account_id       = local.account_id
}

module "rds" {
  source = "./modules/rds"

  project        = var.project
  db_subnet_ids  = module.network.db_subnet_ids
  rds_sg_id      = module.security.rds_sg_id
  db_name        = module.secrets.db_name
  db_username    = module.secrets.db_username
  db_password    = module.secrets.db_password
  multi_az       = var.db_multi_az
  instance_class = var.db_instance_class
}

# Store the full credentials in the secret once the database exists
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = module.secrets.secret_id

  secret_string = jsonencode({
    username = module.secrets.db_username
    password = module.secrets.db_password
    host     = module.rds.address
    port     = module.rds.port
    dbname   = module.secrets.db_name
    engine   = "mysql"
  })
}

module "acm" {
  source = "./modules/acm"

  project = var.project
}

module "alb" {
  source = "./modules/alb"

  project           = var.project
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  certificate_arn   = module.acm.certificate_arn
  app_port          = var.app_port
  logs_bucket_name  = module.s3.logs_bucket_name
  logs_prefix       = module.s3.alb_logs_prefix

  # The logs bucket policy must exist before the ALB is created,
  # otherwise AWS rejects the access-log setting.
  depends_on = [module.s3]
}

# Zip the app folder and upload it to the app bucket
data "archive_file" "app" {
  type        = "zip"
  source_dir  = "${path.root}/../app"
  output_path = "${path.root}/app.zip"
}

resource "aws_s3_object" "app" {
  bucket = module.s3.app_bucket_name
  key    = "releases/app.zip"
  source = data.archive_file.app.output_path
  etag   = data.archive_file.app.output_md5
}

module "compute" {
  source = "./modules/compute"

  project               = var.project
  app_subnet_ids        = module.network.app_subnet_ids
  ec2_sg_id             = module.security.ec2_sg_id
  instance_profile_name = module.iam.instance_profile_name
  target_group_arn      = module.alb.target_group_arn

  instance_type    = var.instance_type
  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size

  app_port        = var.app_port
  region          = var.aws_region
  secret_name     = local.secret_name
  app_bucket_name = module.s3.app_bucket_name
  app_s3_key      = aws_s3_object.app.key
  app_version     = data.archive_file.app.output_md5

  # Servers must start only after the network path (NAT), database,
  # filled-in secret, app package and load balancer all exist.
  depends_on = [
    module.network,
    module.rds,
    aws_secretsmanager_secret_version.db,
    aws_s3_object.app,
    module.alb,
  ]
}
