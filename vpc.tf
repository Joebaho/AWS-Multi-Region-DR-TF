# Primary Region VPC
module "vpc_primary" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.primary
  }

  name = "dr-primary-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.primary_region}a", "${var.primary_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = "dr-primary"
  }
}

# DR Region VPC
module "vpc_dr" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.dr
  }

  name = "dr-secondary-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["${var.dr_region}a", "${var.dr_region}b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = "dr-secondary"
  }
}