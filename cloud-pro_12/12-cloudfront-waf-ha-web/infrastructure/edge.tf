# ---------- AWS WAF ----------
# REGIONAL (default): the web ACL lives in your region and is attached to the ALB.
#   Works in accounts that only allow one region.
# CLOUDFRONT: the web ACL is attached to CloudFront and must be created in us-east-1.

module "waf_regional" {
  source                = "./modules/web_acl"
  count                 = var.waf_scope == "REGIONAL" ? 1 : 0
  name                  = "${local.name_prefix}-waf"
  scope                 = "REGIONAL"
  rate_limit_per_minute = var.rate_limit_per_minute
  use_forwarded_ip      = var.enable_cloudfront # behind CloudFront, the TCP source is a CloudFront server
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_scope == "REGIONAL" ? 1 : 0
  resource_arn = aws_lb.web.arn
  web_acl_arn  = module.waf_regional[0].arn
}

module "waf_global" {
  source                = "./modules/web_acl"
  count                 = var.waf_scope == "CLOUDFRONT" ? 1 : 0
  providers             = { aws = aws.us_east_1 }
  name                  = "${local.name_prefix}-waf"
  scope                 = "CLOUDFRONT"
  rate_limit_per_minute = var.rate_limit_per_minute
}

# ---------- CloudFront ----------
data "aws_cloudfront_cache_policy" "disabled" {
  count = var.enable_cloudfront ? 1 : 0
  name  = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  count = var.enable_cloudfront ? 1 : 0
  name  = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "web" {
  count           = var.enable_cloudfront ? 1 : 0
  provider        = aws.us_east_1
  enabled         = true
  comment         = "${local.name_prefix} edge"
  price_class     = "PriceClass_100" # North America and Europe edge locations only (cheapest)
  web_acl_id      = var.waf_scope == "CLOUDFRONT" ? module.waf_global[0].arn : null
  is_ipv6_enabled = true

  origin {
    origin_id   = "alb"
    domain_name = aws_lb.web.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # see ADR 0003: no custom domain, so no certificate on the ALB
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_secret.result
    }
  }

  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled[0].id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host[0].id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
