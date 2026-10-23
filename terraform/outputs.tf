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