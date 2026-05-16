locals {
  primary_key_name = var.primary_key_name != null ? var.primary_key_name : var.key_name
  dr_key_name      = var.dr_key_name != null ? var.dr_key_name : var.key_name
}

data "aws_ami" "amazon_linux_2_primary" {
  provider    = aws.primary
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux_2_dr" {
  provider    = aws.dr
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
