variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "common_name" {
  description = "Common name placed in the self-signed certificate"
  type        = string
  default     = "demo.devops-practical.local"
}

variable "validity_hours" {
  description = "How long the certificate is valid"
  type        = number
  default     = 168 # 7 days
}