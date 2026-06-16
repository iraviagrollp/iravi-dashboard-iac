# ── WhatsApp Notifier Lambda ───────────────────────────────────────────────────
# Triggered by S3 ObjectCreated on notifications/pending/*.html.
# Phase 1: moves file to notifications/processed/ (validates end-to-end flow).
# Phase 2: reads customer_name from object metadata, looks up mobile_no from
#   customer_details (prepend '91'), fetches bearer token from Secrets Manager
#   (iravi/dashboard/whatsapp), calls Meta WhatsApp Cloud API to send document.
# Source: D:\Projects\Iravi\business-core\lambda\whatsapp_notifier\

locals {
  whatsapp_notifier_name    = "${var.project}-whatsapp-notifier"
  whatsapp_notifier_timeout = 30
  whatsapp_notifier_memory  = 128
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "whatsapp_notifier" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/whatsapp_notifier"
  output_path = "${path.root}/.lambda_build/whatsapp_notifier.zip"
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "whatsapp_notifier" {
  name = "${var.project}-whatsapp-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "whatsapp_notifier" {
  name = "${var.project}-whatsapp-notifier-policy"
  role = aws_iam_role.whatsapp_notifier.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.whatsapp_notifier_name}:*"
      },
      {
        Sid    = "S3Notifications"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.data.arn}/notifications/*"
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "whatsapp_notifier" {
  name              = "/aws/lambda/${local.whatsapp_notifier_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "whatsapp_notifier" {
  function_name    = local.whatsapp_notifier_name
  role             = aws_iam_role.whatsapp_notifier.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.whatsapp_notifier.output_path
  source_code_hash = data.archive_file.whatsapp_notifier.output_base64sha256
  timeout          = local.whatsapp_notifier_timeout
  memory_size      = local.whatsapp_notifier_memory

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.id
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.whatsapp_notifier,
    aws_iam_role_policy.whatsapp_notifier,
  ]

  tags = { Name = local.whatsapp_notifier_name }
}

# ── S3 Trigger Permission ─────────────────────────────────────────────────────
# The aws_s3_bucket_notification block lives in lambda_etl_sales.tf.

resource "aws_lambda_permission" "s3_invoke_whatsapp_notifier" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.whatsapp_notifier.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
