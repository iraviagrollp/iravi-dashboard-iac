# ── ETL Borrowings Lambda ──────────────────────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/Borrowings*.xlsx.
# Parses the Borrowings export (investor/partner borrow-repay ledger) and
# upserts into borrowings (unitemporal milestoning on natural key
# (transaction_date, voucher_no, account)).
# Source: D:\Projects\Iravi\business-core\lambda\etl_borrowings\

locals {
  etl_borrowings_name    = "${var.project}-etl-borrowings"
  etl_borrowings_timeout = 300
  etl_borrowings_memory  = 512
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_borrowings" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_borrowings"
  output_path = "${path.root}/.lambda_build/etl_borrowings.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────
# Linux-compatible wheels (incl. openpyxl — the source file is a real binary
# xlsx, same as etl_stocks / etl_appendix_b_x11) are pip-installed by the
# GitHub Actions workflow step "Build etl_borrowings layer" before terraform
# runs. See .github/workflows/terraform.yml.

data "archive_file" "etl_borrowings_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_borrowings"
  output_path = "${path.root}/.lambda_build/etl_borrowings_layer.zip"
}

resource "aws_lambda_layer_version" "etl_borrowings_deps" {
  filename            = data.archive_file.etl_borrowings_layer.output_path
  layer_name          = "${var.project}-etl-borrowings-deps"
  source_code_hash    = data.archive_file.etl_borrowings_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_borrowings" {
  name = "${var.project}-etl-borrowings-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_borrowings" {
  name = "${var.project}-etl-borrowings-policy"
  role = aws_iam_role.etl_borrowings.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_borrowings_name}:*"
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

resource "aws_cloudwatch_log_group" "etl_borrowings" {
  name              = "/aws/lambda/${local.etl_borrowings_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_borrowings" {
  function_name    = local.etl_borrowings_name
  role             = aws_iam_role.etl_borrowings.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_borrowings.output_path
  source_code_hash = data.archive_file.etl_borrowings.output_base64sha256
  timeout          = local.etl_borrowings_timeout
  memory_size      = local.etl_borrowings_memory
  layers           = [aws_lambda_layer_version.etl_borrowings_deps.arn]

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
    aws_cloudwatch_log_group.etl_borrowings,
    aws_iam_role_policy.etl_borrowings,
  ]

  tags = { Name = local.etl_borrowings_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf.

resource "aws_lambda_permission" "s3_invoke_etl_borrowings" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_borrowings.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
