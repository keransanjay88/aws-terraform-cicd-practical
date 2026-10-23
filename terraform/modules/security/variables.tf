variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security groups in"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}