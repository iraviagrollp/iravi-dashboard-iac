# ── Alerts Evaluator Lambda + EventBridge cron ─────────────────────────────────
# Runs every 15 minutes (rate(15 minutes)).
# Each alert carries its own schedule_time (IST wall-clock); the Lambda
# self-selects which alerts are due for the current 15-minute window.
# Reads active alert rules from the alerts/* tables, queries
# snapshot_customer_balances for matching rows, and emails results via SES.
# Layers:
#   - api_deps    — psycopg2-binary + redis-py (shared with api + redis_updater)
#   - alerts_evaluator_deps — reportlab (PDF generation for Monthly Sales emails)
#     Built by "Build alerts_evaluator_deps layer" CI step.
# Source: ../business-core/lambda/alerts_evaluator/

locals {
  alerts_evaluator_name    = "${var.project}-alerts-evaluator"
  alerts_evaluator_timeout = 300 # 5 min — may process multiple alerts
  alerts_evaluator_memory  = 256
}

# ── Dependency layer (reportlab — PDF generation) ─────────────────────────────
# Built by the "Build alerts_evaluator_deps layer" step in the GitHub Actions
# workflow. reportlab is used to render the Monthly Sales PDF attached to alert
# emails. psycopg2 is already in the shared api_deps layer; this layer is
# alerts_evaluator-specific and should NOT be merged into api_deps.

data "archive_file" "alerts_evaluator_deps_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/alerts_evaluator_deps"
  output_path = "${path.root}/.lambda_build/alerts_evaluator_deps_layer.zip"
}

resource "aws_lambda_layer_version" "alerts_evaluator_deps" {
  filename            = data.archive_file.alerts_evaluator_deps_layer.output_path
  layer_name          = "${var.project}-alerts-evaluator-deps"
  source_code_hash    = data.archive_file.alerts_evaluator_deps_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "alerts_evaluator" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/alerts_evaluator"
  output_path = "${path.root}/.lambda_build/alerts_evaluator.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "alerts_evaluator" {
  name = "${var.project}-alerts-evaluator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "alerts_evaluator" {
  name = "${var.project}-alerts-evaluator-policy"
  role = aws_iam_role.alerts_evaluator.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.alerts_evaluator_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db.arn
      },
      {
        Sid    = "SES"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
        ]
        # Cover both the domain identity (identity/iraviagrolife.com) AND any
        # address-level verified identity under this account+region
        # (e.g. identity/kranthi@iraviagrolife.com, identity/noreply@iraviagrolife.com).
        # SES authorises SendEmail against the *sender* identity ARN, which for an
        # address-verified identity is identity/<address> — not the domain ARN —
        # so scoping to the domain ARN alone causes AccessDenied when the Lambda
        # sends from kranthi@iraviagrolife.com or any other address-level identity.
        Resource = [
          aws_ses_domain_identity.alerts.arn,
          "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/*",
        ]
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "alerts_evaluator" {
  name              = "/aws/lambda/${local.alerts_evaluator_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "alerts_evaluator" {
  function_name    = local.alerts_evaluator_name
  role             = aws_iam_role.alerts_evaluator.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.alerts_evaluator.output_path
  source_code_hash = data.archive_file.alerts_evaluator.output_base64sha256
  timeout          = local.alerts_evaluator_timeout
  memory_size      = local.alerts_evaluator_memory

  # api_deps     — psycopg2-binary for DB access (shared layer).
  # alerts_evaluator_deps — reportlab for PDF generation (this Lambda only).
  layers = [
    aws_lambda_layer_version.api_deps.arn,
    aws_lambda_layer_version.alerts_evaluator_deps.arn,
  ]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN       = aws_secretsmanager_secret.db.arn
      ALERTS_SENDER_EMAIL = var.alerts_sender_email
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.alerts_evaluator,
    aws_iam_role_policy.alerts_evaluator,
  ]

  tags = { Name = local.alerts_evaluator_name }
}

# ── EventBridge rule — every 15 minutes ──────────────────────────────────────
# Previously a daily cron (cron(30 5 * * ? *) = 11:00 IST). Changed to
# rate(15 minutes) so the Lambda can fire per-alert schedule_time windows.
# Send time is now per-alert (alerts.schedule_time, IST); business-core
# owns the logic that selects which alerts are due on each invocation.

resource "aws_cloudwatch_event_rule" "alerts_evaluator_cron" {
  name                = "${var.project}-alerts-evaluator-cron"
  description         = "Triggers alerts_evaluator every 15 minutes; send time is per-alert (alerts.schedule_time)"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "alerts_evaluator" {
  rule      = aws_cloudwatch_event_rule.alerts_evaluator_cron.name
  target_id = "AlertsEvaluatorLambda"
  arn       = aws_lambda_function.alerts_evaluator.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_alerts_evaluator" {
  statement_id  = "AllowEventBridgeCronInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alerts_evaluator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alerts_evaluator_cron.arn
}
