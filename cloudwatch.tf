# SNS Topic for failover alarm events. It lives beside the primary alarm.
resource "aws_sns_topic" "failover_alarm" {
  provider = aws.primary
  name     = "dr-failover-alarm-topic"
}

# SNS Topic for post-failover human notifications.
resource "aws_sns_topic" "failover_notifications" {
  provider = aws.automation
  name     = "dr-failover-notifications"
}

resource "aws_sns_topic_subscription" "notification_email" {
  count     = var.notification_email == null ? 0 : 1
  provider  = aws.automation
  topic_arn = aws_sns_topic.failover_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# CloudWatch Alarm in Primary Region monitors ALB healthy targets.
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  provider   = aws.primary
  alarm_name = "dr-primary-health-alarm"

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Triggered when the primary ALB has no healthy targets"

  dimensions = {
    LoadBalancer = aws_lb.primary.arn_suffix
    TargetGroup  = aws_lb_target_group.primary.arn_suffix
  }

  alarm_actions      = [aws_sns_topic.failover_alarm.arn]
  treat_missing_data = "breaching"
}

# Data source to get the AWS account ID of the primary region
data "aws_caller_identity" "primary" {
  provider = aws.primary
}

# SNS Topic Policy – allows CloudWatch from primary region to publish to this topic
resource "aws_sns_topic_policy" "failover" {
  provider = aws.primary
  arn      = aws_sns_topic.failover_alarm.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchFromPrimaryRegion"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.failover_alarm.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.primary.account_id
          }
        }
      }
    ]
  })
}
