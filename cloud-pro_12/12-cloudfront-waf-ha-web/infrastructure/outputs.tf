output "site_url" {
  description = "The public way in"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.web[0].domain_name}" : "http://${aws_lb.web.dns_name}"
}

output "alb_url" {
  description = "Direct load balancer address (blocked when CloudFront is on)"
  value       = "http://${aws_lb.web.dns_name}"
}

output "cloudfront_enabled" {
  value = var.enable_cloudfront
}

output "asg_name" {
  value = aws_autoscaling_group.web.name
}

output "web_acl_name" {
  value = "${local.name_prefix}-waf"
}

output "waf_scope" {
  description = "Where to find the web ACL in the console: REGIONAL = your region, CLOUDFRONT = Global"
  value       = var.waf_scope
}
