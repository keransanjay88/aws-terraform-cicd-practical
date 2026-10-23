output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "app_subnet_ids" {
  value = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  value = module.network.db_subnet_ids
}

output "ec2_role_arn" {
  value = module.iam.role_arn
}

output "app_bucket_name" {
  value = module.s3.app_bucket_name
}

output "logs_bucket_name" {
  value = module.s3.logs_bucket_name
}

output "rds_endpoint" {
  value = module.rds.address
}

output "certificate_arn" {
  value = module.acm.certificate_arn
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "app_url" {
  value = "https://${module.alb.dns_name}"
}

output "asg_name" {
  value = module.compute.asg_name
}