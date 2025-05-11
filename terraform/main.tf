provider "aws" {
  region = "ap-southeast-1"  # Change to your preferred region
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "my-unique-test-bucket-234asfd"  # Must be globally unique
  acl    = "private"

  tags = {
    Environment = "Test"
    Name        = "TestBucket"
  }
}
