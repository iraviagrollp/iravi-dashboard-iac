# ── ETL Supplier Ledger Lambda ──────────────────────────────────────────────────
# Reads the same "Ledger All Accounts" file as etl_customer_ledger but filters
# for supplier (creditor/payable) account rows and upserts into supplier_ledger
# with uni-temporal milestoning.
#
# Triggered via EventBridge S3 "Object Created" rule on prefix raw/Ledger.
# This avoids the S3 notification 1-target-per-prefix constraint that would
# conflict with the existing etl_customer_ledger S3 notification trigger.
#
# This Lambda is READ-ONLY on S3 — it downloads the object but never writes
# or deletes. It emits NO EventBridge events of its own.
#
# Source: business-core/lambda/etl_supplier_ledger/

locals {
  etl_supplier_ledger_name    = "${var.project}-etl-supplier-ledger"
  etl_supplier_ledger_timeout = 300
  etl_supplier_ledger_memory  = 512
}

# ── Packaging ─────────────────────────────────────────────────────────────────

data "archive_file" "etl_supplier_ledger" {
  type        = "zip"
  source_dir  = "${path.root}/../../../../business-core/lambda/etl_supplier_ledger"
  output_path = "${path.root}/.lambda_build/etl_supplier_ledger.zip"
}

# ── Dependency Layer ───────────────────────────────────────────────────────────
# Linux-compatible wheels are pip-installed by the GitHub Actions workflow step
# "Build etl_supplier_ledger layer" before terraform runs.

data "archive_file" "etl_supplier_ledger_layer" {
  type        = "zip"
  source_dir  = "${path.root}/.lambda_layers/etl_supplier_ledger"
  output_path = "${path.root}/.lambda_build/etl_supplier_ledger_layer.zip"
}

resource "aws_lambda_layer_version" "etl_supplier_ledger_deps" {
  filename            = data.archive_file.etl_supplier_ledger_layer.output_path
  layer_name          = "${var.project}-etl-supplier-ledger-deps"
  source_code_hash    = data.archive_file.etl_supplier_ledger_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "etl_supplier_ledger" {
  name = "${var.project}-etl-supplier-ledger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "etl_supplier_ledger" {
  name = "${var.project}-etl-supplier-ledger-policy"
  role = aws_iam_role.etl_supplier_ledger.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.etl_supplier_ledger_name}:*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db.arn
      },
      # Read-only S3 access — this Lambda never writes or deletes objects.
      {
        Sid      = "S3GetObject"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.data.arn
      },
    ]
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "etl_supplier_ledger" {
  name              = "/aws/lambda/${local.etl_supplier_ledger_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "etl_supplier_ledger" {
  function_name    = local.etl_supplier_ledger_name
  role             = aws_iam_role.etl_supplier_ledger.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.etl_supplier_ledger.output_path
  source_code_hash = data.archive_file.etl_supplier_ledger.output_base64sha256
  timeout          = local.etl_supplier_ledger_timeout
  memory_size      = local.etl_supplier_ledger_memory
  layers           = [aws_lambda_layer_version.etl_supplier_ledger_deps.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATA_BUCKET      = aws_s3_bucket.data.id
      DB_SECRET_ARN    = aws_secretsmanager_secret.db.arn
      RAW_PREFIX       = "raw/"
      PROCESSED_PREFIX = "processed/"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.etl_supplier_ledger,
    aws_iam_role_policy.etl_supplier_ledger,
  ]

  tags = { Name = local.etl_supplier_ledger_name }
}

# ── EventBridge Trigger ────────────────────────────────────────────────────────
# S3 publishes "Object Created" events to EventBridge when eventbridge = true is
# set on the bucket notification (see lambda_etl_sales.tf).
# This rule matches any object created under raw/Ledger in the data bucket.

resource "aws_cloudwatch_event_rule" "s3_ledger_object_created" {
  name        = "${var.project}-s3-ledger-created"
  description = "Fires when an object is created under raw/Ledger in the data bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.data.id]
      }
      object = {
        key = [{ prefix = "raw/Ledger" }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "etl_supplier_ledger" {
  rule      = aws_cloudwatch_event_rule.s3_ledger_object_created.name
  target_id = "EtlSupplierLedgerLambda"
  arn       = aws_lambda_function.etl_supplier_ledger.arn
}

resource "aws_lambda_permission" "eventbridge_invoke_etl_supplier_ledger" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.etl_supplier_ledger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_ledger_object_created.arn
}
