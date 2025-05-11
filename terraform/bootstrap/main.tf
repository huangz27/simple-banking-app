provider "aws" {
  region = var.aws_region
}

# Reference an existing S3 bucket by name
data "aws_s3_bucket" "artifact_bucket" {
  bucket = var.artifact_bucket_name
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "artifact_bucket_ownership" {
  bucket = data.aws_s3_bucket.artifact_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ACL
resource "aws_s3_bucket_acl" "artifact_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.artifact_bucket_ownership]
  bucket     = data.aws_s3_bucket.artifact_bucket.id
  acl        = "private"
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "artifact_bucket_versioning" {
  bucket = data.aws_s3_bucket.artifact_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "artifact_bucket_public_access_block" {
  bucket = data.aws_s3_bucket.artifact_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "artifact_bucket_name" {
  value = data.aws_s3_bucket.artifact_bucket.bucket
}
