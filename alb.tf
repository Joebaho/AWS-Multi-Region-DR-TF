# ALB for Primary Region
resource "aws_lb" "primary" {
  provider = aws.primary
  name     = "dr-primary-alb"
  internal = false

  security_groups = [aws_security_group.web_primary.id]
  subnets         = module.vpc_primary.public_subnets

  tags = {
    Environment = "dr-primary"
  }
}

resource "aws_lb_listener" "primary" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

resource "aws_lb_target_group" "primary" {
  provider = aws.primary
  name     = "dr-primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc_primary.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
  }
}

resource "aws_autoscaling_attachment" "primary" {
  provider               = aws.primary
  autoscaling_group_name = aws_autoscaling_group.primary.id
  lb_target_group_arn    = aws_lb_target_group.primary.arn
}

# ALB for DR Region
resource "aws_lb" "dr" {
  provider = aws.dr
  name     = "dr-secondary-alb"
  internal = false

  security_groups = [aws_security_group.web_dr.id]
  subnets         = module.vpc_dr.public_subnets

  tags = {
    Environment = "dr-secondary"
  }
}

resource "aws_lb_listener" "dr" {
  provider          = aws.dr
  load_balancer_arn = aws_lb.dr.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr.arn
  }
}

resource "aws_lb_target_group" "dr" {
  provider = aws.dr
  name     = "dr-secondary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc_dr.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
  }
}

resource "aws_autoscaling_attachment" "dr" {
  provider               = aws.dr
  autoscaling_group_name = aws_autoscaling_group.dr.id
  lb_target_group_arn    = aws_lb_target_group.dr.arn
}
