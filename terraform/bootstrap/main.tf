# ── Bootstrap ────────────────────────────────────────────────────────────────
# Run this ONCE before the main Terraform config.
# Creates the S3 bucket and DynamoDB table that store Terraform state.
#
# Steps:
#   1. cd terraform/bootstrap
#   2. terraform init
#   3. terraform apply
#   4. Copy the outputs into terraform/main.tf backend block
#   5. cd ../  →  terraform init  →  terraform apply
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "iravi-dashboard-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "IraviDashboard"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "iravi-dashboard-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "IraviDashboard"
    ManagedBy = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

output "state_bucket_name" {
  value = aws_s3_bucket.tfstate.id
}

output "state_lock_table" {
  value = aws_dynamodb_table.tfstate_lock.name
}
