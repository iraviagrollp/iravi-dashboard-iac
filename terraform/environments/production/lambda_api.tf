# ── API Lambda + API Gateway ───────────────────────────────────────────────────
# Serves dashboard data (cache-aside: Redis → RDS fallback → populate Redis) plus
# RBAC auth: POST /auth/login issues a JWT; /auth/me + /admin/* are enforced in the
# Lambda (valid JWT; /admin/* requires an admin user). JWT signing key + bootstrap
# admin creds come from Secrets Manager / Lambda env (see secrets.tf, env block below).
# Cognito JWT authoriser remains a future phase.
# Source: D:\Projects\Iravi\business-core\lambda\api\

locals {
  api_name    = "${var.project}-api"
  api_timeout = 30
  api_memory  = 256
}

# ── Shared dependency layer (api + redis_updater) ─────────────────────────────
# psycopg2-binary and redis-py must be linux-compatible wheels.
# Built by the "Build api-deps layer" step in the GitHub Actions workflow.

data "archive_file" "api_deps_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/api_deps"
  output_path = "${path.root}/.lambda_build/api_deps_layer.zip"
}

resource "aws_lambda_layer_version" "api_deps" {
  filename            = data.archive_file.api_deps_layer.output_path
  layer_name          = "${var.project}-api-deps"
  source_code_hash    = data.archive_file.api_deps_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/api"
  output_path = "${path.root}/.lambda_build/api.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "api" {
  name = "${var.project}-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api" {
  name = "${var.project}-api-policy"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ]
        Resource = "*"
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.api_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.db.arn, aws_secretsmanager_secret.jwt.arn]
      },
      {
        Sid      = "S3Notify"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.data.arn}/notifications/*"
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.api_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "api" {
  function_name    = local.api_name
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  timeout          = local.api_timeout
  memory_size      = local.api_memory
  layers           = [aws_lambda_layer_version.api_deps.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN            = aws_secretsmanager_secret.db.arn
      JWT_SECRET_ARN           = aws_secretsmanager_secret.jwt.arn
      REDIS_HOST               = aws_elasticache_cluster.main.cache_nodes[0].address
      DATA_BUCKET              = aws_s3_bucket.data.id
      BOOTSTRAP_ADMIN_USERNAME = var.dashboard_username
      BOOTSTRAP_ADMIN_PASSWORD = var.dashboard_password
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy.api,
  ]

  tags = { Name = local.api_name }
}

# ── API Gateway (HTTP API v2) ─────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://dashboard.iraviagrolife.com"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "sales" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /sales"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "stocks_summary" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /stocks/summary"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "stocks_current" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /stocks/current"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "ledger_range" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /ledger/range"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "ledger" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /ledger"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "ledger_outstanding" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /ledger/outstanding"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "ledger_statement" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /ledger/statement"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "appendix_b_meta" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /appendix-b/meta"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "appendix_b_report" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /appendix-b/report"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "purchases_meta" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /purchases/meta"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "purchases_summary" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /purchases/summary"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "purchases_monthly" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /purchases/monthly"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "purchases_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /purchases/list"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "sales_meta" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /sales/meta"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "sales_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /sales/list"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "customers_names" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /customers/names"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "customers_details" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /customers/details"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "reports_customer_balances_fy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /reports/customer-balances-fy"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "reports_supplier_balances_fy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /reports/supplier-balances-fy"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "reports_monthly_sales" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /reports/monthly-sales"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "notify" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /notify"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

# ── RBAC: auth + admin routes ─────────────────────────────────────────────────
# Login is public; /auth/me and all /admin/* routes are enforced in the Lambda
# (valid JWT; /admin/* additionally requires an admin user).

locals {
  api_rbac_routes = [
    "POST /auth/login",
    "GET /auth/me",
    "GET /admin/screens",
    "GET /admin/roles",
    "POST /admin/roles",
    "PUT /admin/roles/{role_id}",
    "DELETE /admin/roles/{role_id}",
    "GET /admin/users",
    "POST /admin/users",
    "PUT /admin/users/{user_id}",
    "DELETE /admin/users/{user_id}",
    "POST /admin/cache/flush",
    # ── Alerts — admin-only CRUD + helpers ───────────────────────────────────
    # Enforced in the Lambda handler: valid JWT + is_admin required.
    # CORS already covers GET/POST/PUT/DELETE via the cors_configuration block.
    "GET /alerts",
    "POST /alerts",
    "PUT /alerts/{id}",
    "DELETE /alerts/{id}",
    "GET /alerts/fields",
    "POST /alerts/{id}/test",
    # ── Monthly Sale Targets — admin-only config CRUD ────────────────────────
    # Enforced in the Lambda handler: valid JWT + is_admin required.
    # CORS already covers GET/POST via the cors_configuration block.
    "GET /config/monthly-targets",
    "POST /config/monthly-targets",
  ]
}

resource "aws_apigatewayv2_route" "rbac" {
  for_each  = toset(local.api_rbac_routes)
  api_id    = aws_apigatewayv2_api.main.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_lambda_permission" "apigw_invoke_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
