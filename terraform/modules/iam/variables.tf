variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "secret_arn_pattern" {
  description = "ARN pattern of the one DB secret the instances may read"
  type        = string
}

variable "app_bucket_arn" {
  description = "ARN of the application S3 bucket"
  type        = string
}