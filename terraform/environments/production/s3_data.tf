# ── S3 Data Landing Bucket ────────────────────────────────────────────────────
# Receives FUSIL PRO Excel exports from the File Sync Agent.
# Bucket structure:
#   raw/{date}/*.xlsx     ← File Sync Agent writes here
#   processed/{date}/     ← ETL Lambda moves files here on success
#
# Event notifications live in lambda_etl_sales.tf (aws_s3_bucket_notification).

resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-data-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project}-data" }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
