# ── DB Credentials Secret ─────────────────────────────────────────────────────
# Lambda functions read this secret at cold-start and cache the connection
# for the lifetime of the execution environment.
# Secret key path: iravi/dashboard/db

resource "aws_secretsmanager_secret" "db" {
  name                    = "iravi/dashboard/db"
  description             = "RDS PostgreSQL credentials for the Dashboard DB"
  recovery_window_in_days = 7

  tags = { Name = "${var.project}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

# ── JWT signing key ───────────────────────────────────────────────────────────
# HS256 signing key for dashboard login tokens. Read by the API Lambda
# (business-core/lambda/api/auth.py) at cold start. Stored as a raw string.
# Secret key path: iravi/dashboard/jwt

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "iravi/dashboard/jwt"
  description             = "HS256 signing key for dashboard auth JWTs"
  recovery_window_in_days = 7

  tags = { Name = "${var.project}-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}
