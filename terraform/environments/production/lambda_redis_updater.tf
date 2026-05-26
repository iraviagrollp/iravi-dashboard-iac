# ── Redis Updater Lambda ───────────────────────────────────────────────────────
# Triggered by EventBridge event emitted by etl_sales on successful run.
# Reads key sales metrics from RDS and writes to ElastiCache with 7-day TTL.
# REDIS_HOST env var is added once elasticache.tf is provisioned.
# Source: D:\Projects\Iravi\business-core\lambda\redis_updater\

locals {
  redis_updater_name    = "${var.project}-redis-updater"
  redis_updater_timeout = 60
  redis_updater_memory  = 256
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "redis_updater" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/redis_updater"
  output_path = "${path.root}/.lambda_build/redis_updater.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "redis_updater" {
  name = "${var.project}-redis-updater-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "redis_updater" {
  name = "${var.project}-redis-updater-policy"
  role = aws_iam_role.redis_updater.id

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
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.redis_updater_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db.arn
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "redis_updater" {
  name              = "/aws/lambda/${local.redis_updater_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "redis_updater" {
  function_name    = local.redis_updater_name
  role             = aws_iam_role.redis_updater.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.redis_updater.output_path
  source_code_hash = data.archive_file.redis_updater.output_base64sha256
  timeout          = local.redis_updater_timeout
  memory_size      = local.redis_updater_memory

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = aws_secretsmanager_secret.db.arn
      # REDIS_HOST — added here once elasticache.tf is provisioned
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.redis_updater,
    aws_iam_role_policy.redis_updater,
  ]

  tags = { Name = local.redis_updater_name }
}

# ── EventBridge Trigger ───────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "etl_sales_success" {
  name        = "${var.project}-etl-sales-success"
  description = "Fires when etl_sales Lambda emits ETLSalesSuccess"

  event_pattern = jsonencode({
    source      = ["iravi.etl"]
    detail-type = ["ETLSalesSuccess"]
  })
}

resource "aws_cloudwatch_event_target" "redis_updater" {
  rule      = aws_cloudwatch_event_rule.etl_sales_success.name
  target_id = "RedisUpdaterLambda"
  arn       = aws_lambda_function.redis_updater.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_redis_updater" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redis_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.etl_sales_success.arn
}
