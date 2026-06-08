# ── ETL Customer Accounts Lambda ─────────────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/Customer Accounts Export File*.xlsx.
# Parses the FUSIL PRO Customer Accounts Export, normalises case and state codes,
# and upserts into customer_details (simple upsert on customer_name — no milestoning).
# Source: D:\Projects\Iravi\business-core\lambda\etl_customer_accounts\

locals {
  etl_customer_accounts_name    = "${var.project}-etl-customer-accounts"
  etl_customer_accounts_timeout = 120
  etl_customer_accounts_memory  = 256
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_customer_accounts" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_customer_accounts"
  output_path = "${path.root}/.lambda_build/etl_customer_accounts.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────

data "archive_file" "etl_customer_accounts_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_customer_accounts"
  output_path = "${path.root}/.lambda_build/etl_customer_accounts_layer.zip"
}

resource "aws_lambda_layer_version" "etl_customer_accounts_deps" {
  filename            = data.archive_file.etl_customer_accounts_layer.output_path
  layer_name          = "${var.project}-etl-customer-accounts-deps"
  source_code_hash    = data.archive_file.etl_customer_accounts_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_customer_accounts" {
  name = "${var.project}-etl-customer-accounts-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_customer_accounts" {
  name = "${var.project}-etl-customer-accounts-policy"
  role = aws_iam_role.etl_customer_accounts.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_customer_accounts_name}:*"
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
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "etl_customer_accounts" {
  name              = "/aws/lambda/${local.etl_customer_accounts_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_customer_accounts" {
  function_name    = local.etl_customer_accounts_name
  role             = aws_iam_role.etl_customer_accounts.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_customer_accounts.output_path
  source_code_hash = data.archive_file.etl_customer_accounts.output_base64sha256
  timeout          = local.etl_customer_accounts_timeout
  memory_size      = local.etl_customer_accounts_memory
  layers           = [aws_lambda_layer_version.etl_customer_accounts_deps.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATA_BUCKET   = aws_s3_bucket.data.id
      DB_SECRET_ARN = aws_secretsmanager_secret.db.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.etl_customer_accounts,
    aws_iam_role_policy.etl_customer_accounts,
  ]

  tags = { Name = local.etl_customer_accounts_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf.

resource "aws_lambda_permission" "s3_invoke_etl_customer_accounts" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_customer_accounts.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
