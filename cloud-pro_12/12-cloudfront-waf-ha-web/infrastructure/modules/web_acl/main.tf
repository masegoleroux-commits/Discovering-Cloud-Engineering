terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name" {
  type = string
}

variable "scope" {
  description = "CLOUDFRONT (must be created in us-east-1) or REGIONAL (attached to the ALB)"
  type        = string
}

variable "rate_limit_per_minute" {
  type = number
}

variable "use_forwarded_ip" {
  description = "Count the visitor's IP from X-Forwarded-For (needed when a regional WAF sits behind CloudFront)"
  type        = bool
  default     = false
}

resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = "Rate limiting and AWS managed protections"
  scope       = var.scope

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit                 = var.rate_limit_per_minute
        evaluation_window_sec = 60
        aggregate_key_type    = var.use_forwarded_ip ? "FORWARDED_IP" : "IP"

        dynamic "forwarded_ip_config" {
          for_each = var.use_forwarded_ip ? [1] : []
          content {
            header_name       = "X-Forwarded-For"
            fallback_behavior = "MATCH"
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-common-rules"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-known-bad-inputs"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

output "arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "name" {
  value = aws_wafv2_web_acl.this.name
}
