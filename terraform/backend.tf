terraform {
  backend "s3" {
    bucket         = "tfstate-devops-practical-536438392543"
    key            = "devops-practical/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}