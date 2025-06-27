terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

data "aws_availability_zones" "available" {}