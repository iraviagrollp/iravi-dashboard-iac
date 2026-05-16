# ── Schema Runner ─────────────────────────────────────────────────────────────
# A one-time Lambda that connects to RDS and applies db/schema.sql.
#
# Usage (after terraform apply):
#   1. Upload schema.sql to S3:
#      aws s3 cp db/schema.sql s3://<state-bucket>/schema/schema.sql
#
#   2. Invoke the Lambda:
#      aws lambda invoke \
#        --function-name iravi-dashboard-schema-runner \
#        --payload '{}' \
#        response.json && cat response.json
#
#   3. Check CloudWatch logs for success/error output.
#
# This Lambda is intentionally left in place so future schema changes
# (e.g. adding expense_category column) can be run the same way.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_s3_bucket" "tfstate" {
  bucket = "iravi-dashboard-tfstate-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

# IAM role for Schema Runner Lambda
resource "aws_iam_role" "schema_runner" {
  name = "${var.project}-schema-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "schema_runner" {
  name = "${var.project}-schema-runner-policy"
  role = aws_iam_role.schema_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.db.arn]
      },
      {
        Sid    = "S3ReadSchema"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["${data.aws_s3_bucket.tfstate.arn}/schema/*"]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-schema-runner",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-schema-runner:*",
        ]
      },
      {
        Sid    = "VpcNetworking"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Inline Lambda code — no separate deployment package needed for this utility
data "archive_file" "schema_runner" {
  type        = "zip"
  output_path = "${path.module}/.lambda_build/schema_runner.zip"

  source {
    content  = <<-PYTHON
import json, os, boto3, psycopg2

SECRET_ARN  = os.environ["SECRET_ARN"]
SCHEMA_KEY  = os.environ["SCHEMA_KEY"]
STATE_BUCKET = os.environ["STATE_BUCKET"]

def handler(event, context):
    sm     = boto3.client("secretsmanager")
    creds  = json.loads(sm.get_secret_value(SecretId=SECRET_ARN)["SecretString"])

    s3     = boto3.client("s3")
    sql    = s3.get_object(Bucket=STATE_BUCKET, Key=SCHEMA_KEY)["Body"].read().decode()

    conn   = psycopg2.connect(
        host=creds["host"], port=creds["port"],
        dbname=creds["dbname"], user=creds["username"], password=creds["password"],
        sslmode="require"
    )
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.close()

    print("Schema applied successfully")
    return {"status": "ok"}
    PYTHON
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "schema_runner" {
  function_name    = "${var.project}-schema-runner"
  role             = aws_iam_role.schema_runner.arn
  filename         = data.archive_file.schema_runner.output_path
  source_code_hash = data.archive_file.schema_runner.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 120

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_ARN   = aws_secretsmanager_secret.db.arn
      STATE_BUCKET = data.aws_s3_bucket.tfstate.id
      SCHEMA_KEY   = "schema/schema.sql"
    }
  }

  tags = { Name = "${var.project}-schema-runner" }

  depends_on = [aws_db_instance.main]
}
