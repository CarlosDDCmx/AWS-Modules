// CloudWatch Log Group for the application
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/${var.project_name}/application"
  retention_in_days = 7
  
  tags = {
    Name = "${var.project_name}-app-log-group"
  }
}

// S3 bucket to store the CloudWatch agent configuration file
resource "aws_s3_bucket" "config_bucket" {
  bucket = "${var.project_name}-config-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-config-bucket"
  }
}

// Upload the agent config file to S3
resource "aws_s3_object" "cw_agent_config" {
  bucket = aws_s3_bucket.config_bucket.id
  key    = "cloudwatch-agent-config.json"
  source = "./cloudwatch-agent-config.json" # Assumes file is in the same directory
  etag   = filemd5("./cloudwatch-agent-config.json")
}

// CloudWatch Alarm for high CPU utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_description = "This metric monitors EC2 CPU utilization"
  alarm_actions     = [] # Add SNS topic ARN here for notifications
}

// CloudWatch Alarm for Unhealthy Hosts in the Load Balancer
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  dimensions = {
    TargetGroup      = aws_lb_target_group.frontend_tg.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_description = "This metric monitors for unhealthy hosts in the frontend target group"
  alarm_actions     = [] # Add SNS topic ARN here for notifications
}

// CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.main.name]
          ],
          period = 300,
          stat   = "Average",
          region = var.aws_region,
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.name, { "stat": "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.main.name, { "stat": "Sum" }]
          ],
          view   = "timeSeries",
          stacked= false,
          region = var.aws_region,
          title  = "ALB Target Errors"
        }
      }
    ]
  })
}