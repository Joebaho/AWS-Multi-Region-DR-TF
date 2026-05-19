output "primary_alb_dns" {
  value = aws_lb.primary.dns_name
}

output "dr_alb_dns" {
  value = aws_lb.dr.dns_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.failover_alarm.arn
}

output "notification_topic_arn" {
  value = aws_sns_topic.failover_notifications.arn
}

output "failover_lambda_name" {
  value = aws_lambda_function.failover.function_name
}

output "primary_asg_name" {
  value = aws_autoscaling_group.primary.name
}

output "dr_asg_name" {
  value = aws_autoscaling_group.dr.name
}

output "primary_health_alarm_name" {
  value = aws_cloudwatch_metric_alarm.primary_health.alarm_name
}

output "app_url" {
  value = "http://${var.record_name}"
}
