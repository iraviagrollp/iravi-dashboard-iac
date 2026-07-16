# Inputs for the Procurement stack module. Wired from the root production config
# (see ../procurement.tf) — the module reuses the shared VPC, DB secret, JWT
# secret and api_deps Lambda layer rather than recreating them.

variable "project" {
  description = "Project prefix used in resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the Lambda VPC config"
  type        = list(string)
}

variable "sg_lambda_id" {
  description = "Security group attached to all Lambdas"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for the RDS credentials"
  type        = string
}

variable "jwt_secret_arn" {
  description = "Secrets Manager ARN for the shared JWT signing key"
  type        = string
}

variable "api_deps_layer_arn" {
  description = "ARN of the shared api_deps Lambda layer (psycopg2) — reused, not rebuilt"
  type        = string
}

variable "reportlab_layer_arn" {
  description = "ARN of the shared reportlab Lambda layer (reused for Purchase Order PDF export) — not rebuilt"
  type        = string
}

variable "amplify_github_repo" {
  description = "GitHub repository URL for the Procurement UI"
  type        = string
}

variable "procurement_domain" {
  description = "Custom domain the Procurement UI is served from (API Gateway CORS allow-origin)"
  type        = string
}
