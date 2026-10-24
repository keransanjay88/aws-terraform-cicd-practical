variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "Availability Zones to use (2)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per AZ"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private app subnets, one per AZ"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDRs for private DB subnets, one per AZ"
  type        = list(string)
}

variable "nat_count" {
  description = "Number of NAT Gateways: 1 (cheap demo) or 2 (one per AZ, production)"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2], var.nat_count)
    error_message = "nat_count must be 1 or 2."
  }
}