# ── ETL Customer Ledger Lambda ─────────────────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/Ledger All Accounts*.xlsx.
# Parses the FUSIL PRO Ledger All Accounts export, skips Brought Forward rows,
# and upserts into customer_ledger (unitemporal milestoning on natural key).
# Source: D:\Projects\Iravi\business-core\lambda\etl_customer_ledger\

locals {
  etl_customer_ledger_name    = "${var.project}-etl-customer-ledger"
  etl_customer_ledger_timeout = 300
  etl_customer_ledger_memory  = 512
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_customer_ledger" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_customer_ledger"
  output_path = "${path.root}/.lambda_build/etl_customer_ledger.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────
# Linux-compatible wheels are pip-installed by the GitHub Actions workflow step
# "Build etl_customer_ledger layer" before terraform runs.

data "archive_file" "etl_customer_ledger_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_customer_ledger"
  output_path = "${path.root}/.lambda_build/etl_customer_ledger_layer.zip"
}

resource "aws_lambda_layer_version" "etl_customer_ledger_deps" {
  filename            = data.archive_file.etl_customer_ledger_layer.output_path
  layer_name          = "${var.project}-etl-customer-ledger-deps"
  source_code_hash    = data.archive_file.etl_customer_ledger_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_customer_ledger" {
  name = "${var.project}-etl-customer-ledger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_customer_ledger" {
  name = "${var.project}-etl-customer-ledger-policy"
  role = aws_iam_role.etl_customer_ledger.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_customer_ledger_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db.arn
      },
      {
        Sid      = "S3Data"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "S3List"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.data.arn
      },
      {
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = "*"
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "etl_customer_ledger" {
  name              = "/aws/lambda/${local.etl_customer_ledger_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_customer_ledger" {
  function_name    = local.etl_customer_ledger_name
  role             = aws_iam_role.etl_customer_ledger.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_customer_ledger.output_path
  source_code_hash = data.archive_file.etl_customer_ledger.output_base64sha256
  timeout          = local.etl_customer_ledger_timeout
  memory_size      = local.etl_customer_ledger_memory
  layers           = [aws_lambda_layer_version.etl_customer_ledger_deps.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATA_BUCKET    = aws_s3_bucket.data.id
      DB_SECRET_ARN  = aws_secretsmanager_secret.db.arn
      EVENT_BUS_NAME = "default"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.etl_customer_ledger,
    aws_iam_role_policy.etl_customer_ledger,
  ]

  tags = { Name = local.etl_customer_ledger_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf.

resource "aws_lambda_permission" "s3_invoke_etl_customer_ledger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_customer_ledger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
