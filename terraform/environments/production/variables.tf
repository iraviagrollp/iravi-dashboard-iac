variable "aws_region" {
  description = "AWS region — Mumbai, closest to the business"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "project" {
  description = "Project prefix used in all resource names"
  type        = string
  default     = "iravi-dashboard"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "RDS instance type. Start with t3.small; upgrade to t3.medium if query latency is a concern."
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS storage autoscaling ceiling in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "iravi_dashboard"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "dashboard_admin"
}

variable "backup_retention_days" {
  description = "Automated RDS backup retention in days"
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "Email address to receive pipeline and infrastructure alerts"
  type        = string
}

variable "amplify_github_repo" {
  description = "GitHub repository URL for the dashboard UI (https://github.com/owner/repo)"
  type        = string
  default     = "https://github.com/iraviagrollp/iravi-ui"
}

variable "dashboard_username" {
  description = "Login username for the dashboard UI"
  type        = string
  sensitive   = true
}

variable "dashboard_password" {
  description = "Login password for the dashboard UI"
  type        = string
  sensitive   = true
}

variable "alerts_sender_email" {
  description = "From address for balance-alert emails sent via SES (must belong to alerts_domain)"
  type        = string
  default     = "noreply@iraviagrolife.com"
}

variable "alerts_domain" {
  description = "Domain registered with SES for sending alert emails (e.g. iraviagrolife.com)"
  type        = string
  default     = "iraviagrolife.com"
}

