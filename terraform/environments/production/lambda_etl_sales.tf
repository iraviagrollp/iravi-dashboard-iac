# ── ETL Sales Lambda ───────────────────────────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/*.xlsx.
# Parses the FUSIL PRO sales Excel export and upserts into fact_sales + dim_customers.
# Phase 1 target — sales data only.
# Source: D:\Projects\Iravi\business-core\lambda\etl_sales\

locals {
  etl_sales_name    = "${var.project}-etl-sales"
  etl_sales_timeout = 300 # 5 min — xlsx parse + DB upsert on large files
  etl_sales_memory  = 512 # MB
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_sales" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_sales"
  output_path = "${path.root}/.lambda_build/etl_sales.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_sales" {
  name = "${var.project}-etl-sales-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_sales" {
  name = "${var.project}-etl-sales-policy"
  role = aws_iam_role.etl_sales.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_sales_name}:*"
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

resource "aws_cloudwatch_log_group" "etl_sales" {
  name              = "/aws/lambda/${local.etl_sales_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_sales" {
  function_name    = local.etl_sales_name
  role             = aws_iam_role.etl_sales.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_sales.output_path
  source_code_hash = data.archive_file.etl_sales.output_base64sha256
  timeout          = local.etl_sales_timeout
  memory_size      = local.etl_sales_memory

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN  = aws_secretsmanager_secret.db.arn
      DATA_BUCKET    = aws_s3_bucket.data.id
      EVENT_BUS_NAME = "default"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.etl_sales,
    aws_iam_role_policy.etl_sales,
  ]

  tags = { Name = local.etl_sales_name }
}

# ── S3 Trigger ────────────────────────────────────────────────────────────────

resource "aws_lambda_permission" "s3_invoke_etl_sales" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_sales.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}

# All .xlsx uploads to raw/ fan out to both ETL Lambdas.
# Each handler filters to its own file pattern — do NOT add more notification resources.
resource "aws_s3_bucket_notification" "etl_trigger" {
  bucket = aws_s3_bucket.data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.etl_sales.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".xlsx"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.etl_stocks.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".xlsx"
  }

  depends_on = [
    aws_lambda_permission.s3_invoke_etl_sales,
    aws_lambda_permission.s3_invoke_etl_stocks,
  ]
}
