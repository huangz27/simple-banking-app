# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.app_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.banking_cmk.arn

  tags = {
    Name        = "${var.app_name}-logs"
    Application = var.app_name
  }
}

# CloudWatch Log Group for RDS logs
resource "aws_cloudwatch_log_group" "rds_logs" {
  name              = "/aws/rds/instance/${var.app_name}-postgres"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.banking_cmk.arn

  tags = {
    Name        = "${var.app_name}-rds-logs"
    Application = var.app_name
  }
}

# CloudWatch Dashboard for application monitoring
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app_asg.name]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.banking_db.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app_lb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app_lb.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Response Time"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.banking_db.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Connections"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.banking_db.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Free Storage Space"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", aws_db_instance.banking_db.id],
            ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", aws_db_instance.banking_db.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS IOPS"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.banking_db.id],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", aws_db_instance.banking_db.id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Latency"
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "${var.app_name}-cpu-alarm-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_alarm_high" {
  alarm_name          = "${var.app_name}-rds-cpu-alarm-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors rds cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking_db.id
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.app_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors alb 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.app_lb.arn_suffix
  }
}

# PostgreSQL specific alarms
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space_low" {
  alarm_name          = "${var.app_name}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000  # 2GB in bytes
  alarm_description   = "This metric monitors PostgreSQL free storage space"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking_db.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.app_name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80  # Adjust based on your instance type's connection limit
  alarm_description   = "This metric monitors PostgreSQL connection count"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.banking_db.id
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.app_name}-alerts"
  kms_master_key_id = aws_kms_key.banking_cmk.id
}

# IAM policy for CloudWatch Agent
resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "${var.app_name}-cloudwatch-agent-policy"
  description = "Policy for CloudWatch Agent"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.banking_cmk.arn
      }
    ]
  })
}

# Attach CloudWatch Agent policy to EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_attachment" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

# SSM Parameter for CloudWatch Agent configuration
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "/${var.app_name}/cloudwatch-agent-config"
  type  = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path        = "/var/log/nginx/access.log"
              log_group_name   = aws_cloudwatch_log_group.app_logs.name
              log_stream_name  = "{instance_id}/nginx-access"
              retention_in_days = 30
            },
            {
              file_path        = "/var/log/nginx/error.log"
              log_group_name   = aws_cloudwatch_log_group.app_logs.name
              log_stream_name  = "{instance_id}/nginx-error"
              retention_in_days = 30
            },
            {
              file_path        = "/var/log/app/server.log"
              log_group_name   = aws_cloudwatch_log_group.app_logs.name
              log_stream_name  = "{instance_id}/application"
              retention_in_days = 30
            }
          ]
        }
      }
    },
    metrics = {
      metrics_collected = {
        cpu = {
          resources = ["*"]
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_iowait",
            "cpu_usage_user",
            "cpu_usage_system"
          ]
          totalcpu = true
        },
        mem = {
          measurement = [
            "mem_used_percent"
          ]
        },
        disk = {
          resources = ["/"]
          measurement = [
            "disk_used_percent"
          ]
        }
      },
      append_dimensions = {
        AutoScalingGroupName = "${aws_autoscaling_group.app_asg.name}"
        ImageId              = "${data.aws_ami.amazon_linux.id}"
        InstanceId           = "${aws_launch_template.app_launch_template.id}"
        InstanceType         = "${var.instance_type}"
      }
    }
  })
}