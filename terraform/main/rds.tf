# Security group for RDS
resource "aws_security_group" "db_sg" {
  name        = "banking-db-sg"
  description = "Security group for banking app database"
  vpc_id      = aws_vpc.banking_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "banking-db-sg"
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "banking_db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = var.db_instance_class
  identifier             = banking-db"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  parameter_group_name   = "default.postgres16"
  db_subnet_group_name   = aws_db_subnet_group.banking_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  multi_az               = true
  
  
  # Enable encryption with our CMK
  storage_encrypted = true
  kms_key_id        = aws_kms_key.banking_cmk.arn
  
  # Enable automated backups
  backup_retention_period = 7
  backup_window           = "03:00-05:00"
  maintenance_window      = "Mon:00:00-Mon:03:00"
  
  # Enable deletion protection in production
  deletion_protection = true

  tags = {
    Name = "banking-db"
  }
}

# Initial database schema
resource "aws_ssm_parameter" "db_init_script" {
  name  = "/${var.app_name}/db-init-script"
  type  = "String"
  value = <<-EOT
    CREATE TABLE IF NOT EXISTS accounts (
      id SERIAL PRIMARY KEY,
      account_number VARCHAR(20) UNIQUE NOT NULL,
      balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = CURRENT_TIMESTAMP;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER update_accounts_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

    CREATE TABLE IF NOT EXISTS transactions (
      id SERIAL PRIMARY KEY,
      account_id INTEGER NOT NULL,
      type VARCHAR(10) NOT NULL CHECK (type IN ('deposit', 'withdrawal')),
      amount DECIMAL(15, 2) NOT NULL,
      transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES accounts(id)
    );
  EOT
}