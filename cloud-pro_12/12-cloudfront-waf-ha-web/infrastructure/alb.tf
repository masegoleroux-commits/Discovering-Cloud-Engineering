# A shared secret CloudFront adds to every request. The ALB rejects requests without it,
# so even another CloudFront distribution can't use this origin.
resource "random_password" "origin_secret" {
  length  = 32
  special = false
}

resource "aws_lb" "web" {
  name                       = "${local.name_prefix}-alb"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for s in aws_subnet.public : s.id]
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "web" {
  name                 = "${local.name_prefix}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  # With CloudFront: anything without the secret header gets a 403.
  # Without CloudFront: forward everything (the regional WAF still filters it).
  default_action {
    type             = var.enable_cloudfront ? "fixed-response" : "forward"
    target_group_arn = var.enable_cloudfront ? null : aws_lb_target_group.web.arn

    dynamic "fixed_response" {
      for_each = var.enable_cloudfront ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Direct access is not allowed. Use the CloudFront address."
        status_code  = "403"
      }
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  count        = var.enable_cloudfront ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_secret.result]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
