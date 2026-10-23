# Private key for the certificate (RSA 2048 is what ACM and the ALB accept)
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Self-signed certificate
resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = var.common_name
    organization = "DevOps Practical (self-signed demo)"
  }

  dns_names             = [var.common_name]
  validity_period_hours = var.validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Import it into ACM so the ALB can use it
resource "aws_acm_certificate" "this" {
  private_key      = tls_private_key.this.private_key_pem
  certificate_body = tls_self_signed_cert.this.cert_pem

  tags = { Name = "${var.project}-self-signed-cert" }

  lifecycle {
    create_before_destroy = true
  }
}