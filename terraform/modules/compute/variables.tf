variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "app_subnet_ids" {
  description = "Private app subnet IDs (one per AZ)"
  type        = list(string)
}

variable "ec2_sg_id" {
  description = "Security group for the instances"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group to register instances with"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 2
}

variable "health_check_grace_period" {
  description = "Seconds to wait before health checks can replace a new instance"
  type        = number
  default     = 300
}

variable "app_port" {
  type = number
}

variable "region" {
  type = string
}

variable "secret_name" {
  description = "Name of the DB secret (only the name, never the value)"
  type        = string
}

variable "app_bucket_name" {
  type = string
}

variable "app_s3_key" {
  description = "S3 key of the zipped application"
  type        = string
}

variable "app_version" {
  description = "Hash of the app package; a change triggers an instance refresh"
  type        = string
}