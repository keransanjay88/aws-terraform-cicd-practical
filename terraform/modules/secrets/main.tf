# Strong random password. Characters RDS MySQL does not allow
# (/ @ " and space) are excluded by choosing our own special set.
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#%^*()-_=+"
}

# The secret container. Encrypted by default with the free AWS-managed key
# (aws/secretsmanager).
resource "aws_secretsmanager_secret" "db" {
  name                    = var.secret_name
  description             = "Database credentials for the application"
  recovery_window_in_days = 0 # delete immediately on destroy (demo only)
}