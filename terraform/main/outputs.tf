output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.app_alb.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.banking_db.endpoint
}

output "test_account_number" {
  description = "Test account number for API testing"
  value       = "12345678"
}

output "api_endpoints" {
  description = "API endpoints for the banking application"
  value = {
    balance      = "http://${aws_lb.app_alb.dns_name}/api/balance/12345678"
    deposit      = "http://${aws_lb.app_alb.dns_name}/api/deposit"
    withdraw     = "http://${aws_lb.app_alb.dns_name}/api/withdraw"
    transactions = "http://${aws_lb.app_alb.dns_name}/api/transactions/12345678"
  }
}

output "secrets_manager_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "ami_id" {
  description = "AMI ID used for EC2 instances"
  value       = data.aws_ami.amazon_linux_2.id
}

output "ami_name" {
  description = "AMI name used for EC2 instances"
  value       = data.aws_ami.amazon_linux_2.name
}