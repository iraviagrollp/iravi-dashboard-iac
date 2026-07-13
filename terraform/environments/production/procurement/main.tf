# ── Procurement stack ─────────────────────────────────────────────────────────
# Segregated module for the Procurement dashboard (procurement.iraviagrolife.com):
#   - procurement_api Lambda (CRUD over the `procurement.*` schema; shared RBAC login)
#   - its own API Gateway HTTP API (v2)
#   - its own Amplify app (env vars only; connected to GitHub manually)
#
# Reuses the shared VPC, DB secret, JWT secret and api_deps layer from the root
# production config. Source: D:\Projects\Iravi\business-core\lambda\procurement_api\

locals {
  fn_name     = "${var.project}-procurement-api"
  api_timeout = 30
  api_memory  = 256
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "procurement_api" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/procurement_api"
  output_path = "${path.root}/.lambda_build/procurement_api.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "procurement_api" {
  name = "${var.project}-procurement-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "procurement_api" {
  name = "${var.project}-procurement-api-policy"
  role = aws_iam_role.procurement_api.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.fn_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn, var.jwt_secret_arn]
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "procurement_api" {
  name              = "/aws/lambda/${local.fn_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "procurement_api" {
  function_name    = local.fn_name
  role             = aws_iam_role.procurement_api.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.procurement_api.output_path
  source_code_hash = data.archive_file.procurement_api.output_base64sha256
  timeout          = local.api_timeout
  memory_size      = local.api_memory
  layers           = [var.api_deps_layer_arn]

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN  = var.db_secret_arn
      JWT_SECRET_ARN = var.jwt_secret_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.procurement_api,
    aws_iam_role_policy.procurement_api,
  ]

  tags = { Name = local.fn_name }
}

# ── API Gateway (HTTP API v2) ─────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "procurement" {
  name          = "${var.project}-procurement-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${var.procurement_domain}"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.procurement.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "procurement" {
  api_id                 = aws_apigatewayv2_api.procurement.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.procurement_api.invoke_arn
  payload_format_version = "2.0"
}

locals {
  procurement_routes = [
    "POST /auth/login",
    "GET /auth/me",
    # Technicals
    "GET /technicals",
    "POST /technicals",
    "PUT /technicals/{id}",
    "DELETE /technicals/{id}",
    # Supplier companies
    "GET /supplier-companies",
    "POST /supplier-companies",
    "PUT /supplier-companies/{id}",
    "DELETE /supplier-companies/{id}",
    # Suppliers
    "GET /suppliers",
    "POST /suppliers",
    "PUT /suppliers/{id}",
    "DELETE /suppliers/{id}",
    # Enquiries
    "GET /enquiries",
    "POST /enquiries",
    "PUT /enquiries/{id}",
    "DELETE /enquiries/{id}",
    # PDC
    "GET /pdc",
    "POST /pdc",
    "PUT /pdc/{id}",
    "DELETE /pdc/{id}",
  ]
}

resource "aws_apigatewayv2_route" "procurement" {
  for_each  = toset(local.procurement_routes)
  api_id    = aws_apigatewayv2_api.procurement.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.procurement.id}"
}

resource "aws_lambda_permission" "apigw_invoke_procurement" {
  statement_id  = "AllowAPIGatewayInvokeProcurement"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procurement_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.procurement.execution_arn}/*/*"
}

# ── Amplify Hosting ───────────────────────────────────────────────────────────
# ONE-TIME IMPORT REQUIRED — connect the procurement-ui repo in the Amplify console
# first, then bring the app into state before the first apply:
#   terraform import 'module.procurement.aws_amplify_app.procurement' <AMPLIFY_APP_ID>
# The custom domain (procurement.iraviagrolife.com) is attached in the Amplify
# console + a CNAME at the DNS provider (same manual flow as the dashboard app).

resource "aws_amplify_app" "procurement" {
  name       = "${var.project}-procurement-ui"
  repository = var.amplify_github_repo

  environment_variables = {
    VITE_API_BASE_URL = aws_apigatewayv2_stage.default.invoke_url
  }

  lifecycle {
    ignore_changes = [oauth_token, platform, build_spec, custom_rule]
  }

  tags = { Name = "${var.project}-procurement-ui" }
}
