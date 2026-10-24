variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the load balancer"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
}

variable "logs_bucket_name" {
  description = "S3 bucket for ALB access logs"
  type        = string
}

variable "logs_prefix" {
  description = "Folder inside the logs bucket"
  type        = string
}

variable "health_check_path" {
  description = "Path the load balancer calls to check a server"
  type        = string
  default     = "/health"
}