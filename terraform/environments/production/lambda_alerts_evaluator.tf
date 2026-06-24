# ── Alerts Evaluator Lambda + EventBridge cron ─────────────────────────────────
# Runs every 15 minutes (rate(15 minutes)).
# Each alert carries its own schedule_time (IST wall-clock); the Lambda
# self-selects which alerts are due for the current 15-minute window.
# Reads active alert rules from the alerts/* tables, queries
# snapshot_customer_balances for matching rows, and emails results via SES.
# Layer: reuses api_deps (psycopg2-binary + redis-py) — no new pip layer needed.
# Source: ../business-core/lambda/alerts_evaluator/

locals {
  alerts_evaluator_name    = "${var.project}-alerts-evaluator"
  alerts_evaluator_timeout = 300 # 5 min — may process multiple alerts
  alerts_evaluator_memory  = 256
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
        # Scope to the verified domain identity ARN only
        Resource = aws_ses_domain_identity.alerts.arn
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

  # Reuse api_deps layer — provides psycopg2-binary (DB access).
  # No additional layer is required for this Lambda.
  layers = [aws_lambda_layer_version.api_deps.arn]

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
