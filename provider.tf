terraform {
  required_version = "~> 1.5" # Ensures you are using a compatible Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Pins the AWS provider to version 5.x
    }
  }
}