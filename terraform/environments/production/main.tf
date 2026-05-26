terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Fill in bucket and dynamodb_table from bootstrap outputs, then run:
  #   terraform init -reconfigure
  backend "s3" {
    bucket         = "iravi-dashboard-tfstate-227037612364"
    key            = "infra/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "iravi-dashboard-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "IraviDashboard"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
