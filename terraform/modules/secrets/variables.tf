variable "secret_name" {
  description = "Name of the secret in Secrets Manager"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "appdb"
}