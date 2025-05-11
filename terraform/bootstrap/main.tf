provider "aws" {
  region = "ap-southeast-1"
}

# S3 bucket for application files
resource "aws_s3_bucket" "app_bucket" {
  bucket_prefix = "${var.app_name}-files-"
  force_destroy = true
  
  tags = {
    Name        = "${var.app_name}-files"
    Application = var.app_name
  }
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "app_bucket_ownership" {
  bucket = aws_s3_bucket.app_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ACL
resource "aws_s3_bucket_acl" "app_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.app_bucket_ownership]
  bucket     = aws_s3_bucket.app_bucket.id
  acl        = "private"
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "app_bucket_public_access_block" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
