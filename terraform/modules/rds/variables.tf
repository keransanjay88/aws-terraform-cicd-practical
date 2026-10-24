variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "db_subnet_ids" {
  description = "Private DB subnet IDs (one per AZ)"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for the database"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "db_username" {
  description = "Master username"
  type        = string
}

variable "db_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Multi-AZ standby: false for the cheap demo, true for production"
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "MySQL major version"
  type        = string
  default     = "8.4"
}

variable "parameter_group_family" {
  description = "Parameter group family matching the engine version"
  type        = string
  default     = "mysql8.4"
}