####################################################
# S3 Bucket for MWAA DAGs, Plugins, and Requirements
####################################################

resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.project_name}-${var.environment}-mwaa-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-mwaa-bucket"
  }
}

# Get current AWS account ID for unique bucket naming
data "aws_caller_identity" "current" {}

# ---------- Versioning (required by MWAA) ----------
resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------- Block all public access ----------
resource "aws_s3_bucket_public_access_block" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- Server-side encryption ----------
resource "aws_s3_bucket_server_side_encryption_configuration" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ---------- Lifecycle rules (clean up old versions) ----------
resource "aws_s3_bucket_lifecycle_configuration" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ---------- Upload initial requirements.txt ----------
resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.mwaa.id
  key    = var.requirements_s3_path
  source = "${path.module}/../requirements/requirements.txt"
  etag   = filemd5("${path.module}/../requirements/requirements.txt")
}
