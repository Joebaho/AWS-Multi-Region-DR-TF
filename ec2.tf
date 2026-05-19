# Security Group for web servers (Primary)
resource "aws_security_group" "web_primary" {
  provider = aws.primary
  name     = "dr-web-sg-primary"
  vpc_id   = module.vpc_primary.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_primary" {
  provider = aws.primary
  name     = "dr-instance-sg-primary"
  vpc_id   = module.vpc_primary.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_primary.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for web servers (DR)
resource "aws_security_group" "web_dr" {
  provider = aws.dr
  name     = "dr-web-sg-dr"
  vpc_id   = module.vpc_dr.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_dr" {
  provider = aws.dr
  name     = "dr-instance-sg-dr"
  vpc_id   = module.vpc_dr.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_dr.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for Primary Region
resource "aws_launch_template" "primary" {
  provider = aws.primary
  name     = "dr-primary-lt"

  image_id      = data.aws_ami.amazon_linux_2_primary.id
  instance_type = var.instance_type
  key_name      = local.primary_key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Primary Region - $(hostname -f)</h1>" > /var/www/html/index.html
    EOF
  )

  vpc_security_group_ids = [aws_security_group.instance_primary.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "dr-primary-instance"
    }
  }
}

# Auto Scaling Group for Primary Region
resource "aws_autoscaling_group" "primary" {
  provider = aws.primary
  name     = "dr-primary-asg"

  min_size          = 2
  max_size          = 4
  desired_capacity  = 2
  health_check_type = "ELB"

  vpc_zone_identifier = module.vpc_primary.private_subnets

  launch_template {
    id      = aws_launch_template.primary.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "dr-primary-instance"
    propagate_at_launch = true
  }
}

# Launch Template for DR Region (starts stopped)
resource "aws_launch_template" "dr" {
  provider = aws.dr
  name     = "dr-secondary-lt"

  image_id      = data.aws_ami.amazon_linux_2_dr.id
  instance_type = var.instance_type
  key_name      = local.dr_key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from DR Region - $(hostname -f)</h1>" > /var/www/html/index.html
    EOF
  )

  vpc_security_group_ids = [aws_security_group.instance_dr.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "dr-secondary-instance"
    }
  }
}

# Auto Scaling Group for DR Region (min_size=0, max_size=3)
resource "aws_autoscaling_group" "dr" {
  provider = aws.dr
  name     = "dr-secondary-asg"

  min_size          = 0
  max_size          = 4
  desired_capacity  = 0
  health_check_type = "ELB"

  vpc_zone_identifier = module.vpc_dr.private_subnets

  launch_template {
    id      = aws_launch_template.dr.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "dr-secondary-instance"
    propagate_at_launch = true
  }
}
