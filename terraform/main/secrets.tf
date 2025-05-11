# AWS Secrets Manager for database credentials
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.app_name}-pgsql-credentials-${random_id.suffix.hex}"
  description = "Database credentials for ${var.app_name}"
  kms_key_id  = aws_kms_key.banking_cmk.arn

  lifecycle {
    prevent_destroy = true
  }
  
  tags = {
    Name = "${var.app_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.banking_db.address
    port     = 5432
    dbname   = var.db_name
  })
}

# IAM policy for EC2 instances to access Secrets Manager
resource "aws_iam_policy" "secrets_policy" {
  name        = "${var.app_name}-secrets-policy"
  description = "Allow access to Secrets Manager for database credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.banking_cmk.arn
      }
    ]
  })
}

# Attach Secrets Manager policy to role
resource "aws_iam_role_policy_attachment" "secrets_policy_attachment" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}