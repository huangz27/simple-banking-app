# Banking App Terraform Infrastructure

This repository contains Terraform code to deploy a secure, scalable banking application infrastructure on AWS.

## Architecture Overview

The infrastructure includes:

- VPC with public, private, and database subnets across multiple availability zones
- Auto Scaling Group with EC2 instances in private subnets
- Application Load Balancer in public subnets
- RDS PostgreSQL database with encryption and high availability
- Secrets Manager for secure credential management
- KMS for encryption of sensitive data
- CloudWatch for monitoring and logging
- SNS for alerting

## Security Features

- **KMS Customer Managed Key (CMK)** for encryption of:
  - RDS database storage
  - Secrets Manager secrets
  - CloudWatch logs
  - S3 bucket objects
- **Enhanced RDS Security**:
  - Storage encryption
  - Performance Insights with encryption
  - Enhanced monitoring
  - Automated backups
  - Multi-AZ deployment
- **Network Security**:
  - Private subnets for application and database tiers
  - Security groups with least privilege access
  - NAT Gateway for outbound internet access
- **IAM Security**:
  - Instance profiles with least privilege permissions
  - Service roles with specific permissions
- **Instance Security**:
  - IMDSv2 required
  - User data script for secure configuration

## Monitoring and Logging

- **CloudWatch Dashboards** for application and infrastructure metrics
- **CloudWatch Alarms** for critical thresholds
- **CloudWatch Logs** for application and system logs
- **SNS Topics** for alerts and notifications
- **Auto Scaling** based on CPU utilization

## Project Structure

```
banking-app-terraform/
├── main.tf              # Main infrastructure configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── app.tf               # Application infrastructure (EC2, ASG, etc.)
├── alb.tf               # Application Load Balancer configuration
├── rds.tf               # PostgreSQL database configuration
├── secrets.tf           # Secrets Manager configuration
├── kms.tf               # KMS key configuration
├── monitoring.tf        # CloudWatch monitoring and logging
├── scripts/
│   └── user-data.sh     # EC2 instance user data script
└── README.md            # Project documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform v1.0.0 or newer
- An AWS account with permissions to create the resources

## Deployment Instructions

0. Build and upload the app related code and upload to S3
1. Initialize Terraform:
   ```
   terraform init
   ```

2. Review the execution plan:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

4. Confirm the changes by typing `yes` when prompted.

## Post-Deployment Steps

1. Verify that the EC2 instances are running and healthy in the ASG
2. Test the application through the ALB endpoint
3. Verify that logs are being sent to CloudWatch
4. Test the SNS notifications

## Clean Up

To destroy all resources created by Terraform:
```
terraform destroy
```

## Important Notes

- The RDS instance has deletion protection enabled. To delete it, you must first modify the instance to disable deletion protection.
- KMS keys have a deletion waiting period of 30 days by default.
- Remember to rotate the KMS key regularly for enhanced security.