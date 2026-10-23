variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "devops-practical"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "keran"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "nat_count" {
  description = "NAT Gateways: 1 for the cheap demo, 2 for production HA"
  type        = number
  default     = 1
}