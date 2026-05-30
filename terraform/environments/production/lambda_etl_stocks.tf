# ── ETL Stocks Lambda ──────────────────────────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/Current Stock Balances*.xlsx.
# Parses stock balance xlsx, joins rates from Product Masters With Rates*.xlsx,
# writes processed output to processed/Stock - Processed <date>.xlsx.
# Source: D:\Projects\Iravi\business-core\lambda\etl_stocks\
#
# Bucket notification lives in lambda_etl_sales.tf (one resource per bucket).

locals {
  etl_stocks_name    = "${var.project}-etl-stocks"
  etl_stocks_timeout = 300 # 5 min — xlsx parse can be slow on large files
  etl_stocks_memory  = 512 # MB
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_stocks" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_stocks"
  output_path = "${path.root}/.lambda_build/etl_stocks.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────
# pip installs Linux-compatible wheels into .lambda_layers/etl_stocks/python/
# during terraform apply (runs in GitHub Actions — no local install needed).
# Triggered only when requirements.txt changes.

resource "null_resource" "etl_stocks_deps" {
  triggers = {
    requirements_hash = filemd5("${path.root}/../../../../business-core/lambda/etl_stocks/requirements.txt")
  }

  provisioner "local-exec" {
    command = "python -m pip install -r \"${path.root}/../../../../business-core/lambda/etl_stocks/requirements.txt\" -t \"${path.root}/.lambda_layers/etl_stocks/python\" --platform manylinux2014_x86_64 --implementation cp --python-version 3.12 --only-binary=:all: --upgrade --quiet"
  }
}

data "archive_file" "etl_stocks_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_stocks"
  output_path = "${path.root}/.lambda_build/etl_stocks_layer.zip"
  depends_on  = [null_resource.etl_stocks_deps]
}

resource "aws_lambda_layer_version" "etl_stocks_deps" {
  filename            = data.archive_file.etl_stocks_layer.output_path
  layer_name          = "${var.project}-etl-stocks-deps"
  source_code_hash    = data.archive_file.etl_stocks_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_stocks" {
  name = "${var.project}-etl-stocks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_stocks" {
  name = "${var.project}-etl-stocks-policy"
  role = aws_iam_role.etl_stocks.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_stocks_name}:*"
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

resource "aws_cloudwatch_log_group" "etl_stocks" {
  name              = "/aws/lambda/${local.etl_stocks_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_stocks" {
  function_name    = local.etl_stocks_name
  role             = aws_iam_role.etl_stocks.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_stocks.output_path
  source_code_hash = data.archive_file.etl_stocks.output_base64sha256
  timeout          = local.etl_stocks_timeout
  memory_size      = local.etl_stocks_memory
  layers           = [aws_lambda_layer_version.etl_stocks_deps.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.id
      # RAW_PREFIX and PROCESSED_PREFIX use handler defaults (raw/ and processed/)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.etl_stocks,
    aws_iam_role_policy.etl_stocks,
  ]

  tags = { Name = local.etl_stocks_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf and references
# this permission via depends_on. Add this function there.

resource "aws_lambda_permission" "s3_invoke_etl_stocks" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_stocks.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
