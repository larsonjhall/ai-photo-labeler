terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. ADD THIS: The Default Provider (No Alias)
# This keeps the "orphaned" resources happy
provider "aws" {
  region = "us-east-1"
}

# 2. Your Aliased Providers (The ones you're using for the new VPCs)
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}