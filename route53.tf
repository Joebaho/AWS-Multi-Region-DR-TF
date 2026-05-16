data "aws_route53_zone" "domain" {
  provider     = aws.automation
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "app" {
  provider = aws.automation
  zone_id  = data.aws_route53_zone.domain.zone_id
  name     = var.record_name
  type     = "A"

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }
}
