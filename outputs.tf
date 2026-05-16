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
