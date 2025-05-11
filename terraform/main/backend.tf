terraform {
  backend "s3" {
    bucket = "var.artifact_bucket"
    key    = "main/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
