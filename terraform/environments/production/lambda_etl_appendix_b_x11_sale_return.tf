# ── ETL Appendix B X11 Sale Return Lambda ─────────────────────────────────────
# Triggered by S3 ObjectCreated on raw/AppendixRetSales*.xlsx.
# Parses the FUSIL PRO sales return report, looks up mdf_date/exp_date from
# appendix_b_x11_stock, and upserts into appendix_b_x11_stock_ledger with
# in_out = 'In' and uni-temporal milestoning on
# (purchase_date, iravi_voucher, technical_name, barcode).
# Source: D:\Projects\Iravi\business-core\lambda\etl_appendix_b_x11_sale_return\

locals {
  etl_appendix_b_x11_sale_return_name    = "${var.project}-etl-appendix-b-x11-sale-return"
  etl_appendix_b_x11_sale_return_timeout = 120
  etl_appendix_b_x11_sale_return_memory  = 256
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_appendix_b_x11_sale_return" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_appendix_b_x11_sale_return"
  output_path = "${path.root}/.lambda_build/etl_appendix_b_x11_sale_return.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────

data "archive_file" "etl_appendix_b_x11_sale_return_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_appendix_b_x11_sale_return"
  output_path = "${path.root}/.lambda_build/etl_appendix_b_x11_sale_return_layer.zip"
}

resource "aws_lambda_layer_version" "etl_appendix_b_x11_sale_return_deps" {
  filename            = data.archive_file.etl_appendix_b_x11_sale_return_layer.output_path
  layer_name          = "${var.project}-etl-appendix-b-x11-sale-return-deps"
  source_code_hash    = data.archive_file.etl_appendix_b_x11_sale_return_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_appendix_b_x11_sale_return" {
  name = "${var.project}-etl-appendix-b-x11-sale-return-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_appendix_b_x11_sale_return" {
  name = "${var.project}-etl-appendix-b-x11-sale-return-policy"
  role = aws_iam_role.etl_appendix_b_x11_sale_return.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_appendix_b_x11_sale_return_name}:*"
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

resource "aws_cloudwatch_log_group" "etl_appendix_b_x11_sale_return" {
  name              = "/aws/lambda/${local.etl_appendix_b_x11_sale_return_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_appendix_b_x11_sale_return" {
  function_name    = local.etl_appendix_b_x11_sale_return_name
  role             = aws_iam_role.etl_appendix_b_x11_sale_return.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_appendix_b_x11_sale_return.output_path
  source_code_hash = data.archive_file.etl_appendix_b_x11_sale_return.output_base64sha256
  timeout          = local.etl_appendix_b_x11_sale_return_timeout
  memory_size      = local.etl_appendix_b_x11_sale_return_memory
  layers           = [aws_lambda_layer_version.etl_appendix_b_x11_sale_return_deps.arn]

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
    aws_cloudwatch_log_group.etl_appendix_b_x11_sale_return,
    aws_iam_role_policy.etl_appendix_b_x11_sale_return,
  ]

  tags = { Name = local.etl_appendix_b_x11_sale_return_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf.

resource "aws_lambda_permission" "s3_invoke_etl_appendix_b_x11_sale_return" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_appendix_b_x11_sale_return.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
