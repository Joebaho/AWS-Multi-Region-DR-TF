# IAM Role for Lambda
resource "aws_iam_role" "failover_lambda" {
  provider = aws.automation
  name     = "dr-failover-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "failover_lambda" {
  provider = aws.automation
  name     = "dr-failover-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:GetHostedZone"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.failover_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "failover_lambda" {
  provider   = aws.automation
  role       = aws_iam_role.failover_lambda.name
  policy_arn = aws_iam_policy.failover_lambda.arn
}

# Lambda Function (Python 3.12)
resource "aws_lambda_function" "failover" {
  provider      = aws.automation
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "dr-failover-handler"
  role          = aws_iam_role.failover_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300

  environment {
    variables = {
      DOMAIN_NAME         = var.record_name
      HOSTED_ZONE_ID      = data.aws_route53_zone.domain.zone_id
      DR_ALB_DNS          = aws_lb.dr.dns_name
      DR_ALB_ZONE_ID      = aws_lb.dr.zone_id
      DR_TARGET_GROUP_ARN = aws_lb_target_group.dr.arn
      PRIMARY_ASG_NAME    = aws_autoscaling_group.primary.name
      DR_ASG_NAME         = aws_autoscaling_group.dr.name
      PRIMARY_REGION      = var.primary_region
      DR_REGION           = var.dr_region
      SNS_TOPIC_ARN       = aws_sns_topic.failover_notifications.arn
    }
  }
}

# Package Lambda code into a ZIP archive
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

# SNS Topic subscription to invoke Lambda
resource "aws_sns_topic_subscription" "failover_lambda" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.failover_alarm.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.failover.arn
}

resource "aws_lambda_permission" "sns" {
  provider      = aws.automation
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.failover_alarm.arn
}
