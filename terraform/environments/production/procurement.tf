# ── Procurement stack instantiation ───────────────────────────────────────────
# Segregated in ./procurement/. Reuses the shared VPC, DB secret, JWT secret and
# api_deps Lambda layer (psycopg2) declared elsewhere in this config.

module "procurement" {
  source = "./procurement"

  project    = var.project
  aws_region = var.aws_region

  private_subnet_ids = aws_subnet.private[*].id
  sg_lambda_id       = aws_security_group.lambda.id

  db_secret_arn       = aws_secretsmanager_secret.db.arn
  jwt_secret_arn      = aws_secretsmanager_secret.jwt.arn
  api_deps_layer_arn  = aws_lambda_layer_version.api_deps.arn
  reportlab_layer_arn = aws_lambda_layer_version.alerts_evaluator_deps.arn

  amplify_github_repo = var.procurement_amplify_github_repo
  procurement_domain  = var.procurement_domain
}

output "procurement_api_endpoint" {
  description = "Procurement API Gateway base URL — set as VITE_API_BASE_URL in the procurement-ui Amplify app"
  value       = module.procurement.procurement_api_endpoint
}

output "procurement_amplify_default_domain" {
  description = "Amplify-assigned domain for the Procurement UI"
  value       = module.procurement.procurement_amplify_default_domain
}
