variable "app_bucket_name" {
  description = "Name of the application bucket"
  type        = string
}

variable "logs_bucket_name" {
  description = "Name of the ALB access logs bucket"
  type        = string
}

variable "account_id" {
  description = "AWS account ID (used in the ALB log path)"
  type        = string
}

variable "alb_logs_prefix" {
  description = "Folder inside the logs bucket where the ALB writes"
  type        = string
  default     = "alb"
}

variable "logs_retention_days" {
  description = "Days before ALB logs are deleted"
  type        = number
  default     = 7
}