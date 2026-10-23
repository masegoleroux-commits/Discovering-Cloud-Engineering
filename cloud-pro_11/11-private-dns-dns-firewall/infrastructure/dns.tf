# ---------- Private hosted zone: names only this VPC can resolve ----------
resource "aws_route53_zone" "private" {
  name          = var.private_zone_name
  comment       = "Internal names for ${local.name_prefix}"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "service" {
  for_each = aws_network_interface.service
  zone_id  = aws_route53_zone.private.zone_id
  name     = "${each.key}.${var.private_zone_name}"
  type     = "A"
  ttl      = 60
  records  = [each.value.private_ip]
}

resource "aws_route53_record" "api_alias" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${var.private_zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = ["app.${var.private_zone_name}"]
}

# Where sinkholed lookups are sent. 192.0.2.1 is a reserved documentation address (RFC 5737).
resource "aws_route53_record" "sinkhole" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "sinkhole.${var.private_zone_name}"
  type    = "A"
  ttl     = 60
  records = ["192.0.2.1"]
}

resource "aws_route53_record" "owner" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "_owner.${var.private_zone_name}"
  type    = "TXT"
  ttl     = 300
  records = ["managed-by=terraform owner=${var.owner}"]
}

# ---------- Route 53 Resolver DNS Firewall ----------
resource "aws_route53_resolver_firewall_domain_list" "blocked" {
  name    = "${local.name_prefix}-blocked"
  domains = var.blocked_domains
}

resource "aws_route53_resolver_firewall_domain_list" "sinkholed" {
  name    = "${local.name_prefix}-sinkholed"
  domains = var.sinkholed_domains
}

resource "aws_route53_resolver_firewall_domain_list" "alert" {
  name    = "${local.name_prefix}-alert"
  domains = var.alert_domains
}

resource "aws_route53_resolver_firewall_rule_group" "main" {
  name = "${local.name_prefix}-rules"
}

resource "aws_route53_resolver_firewall_rule" "block" {
  name                    = "block-nxdomain"
  action                  = "BLOCK"
  block_response          = "NXDOMAIN"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.blocked.id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main.id
  priority                = 100
}

resource "aws_route53_resolver_firewall_rule" "sinkhole" {
  name                    = "block-sinkhole"
  action                  = "BLOCK"
  block_response          = "OVERRIDE"
  block_override_dns_type = "CNAME"
  block_override_domain   = "sinkhole.${var.private_zone_name}."
  block_override_ttl      = 60
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.sinkholed.id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main.id
  priority                = 200
}

resource "aws_route53_resolver_firewall_rule" "alert" {
  name                    = "alert-only"
  action                  = "ALERT"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.alert.id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main.id
  priority                = 300
}

resource "aws_route53_resolver_firewall_rule_group_association" "vpc" {
  name                   = "${local.name_prefix}-rules-vpc"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.main.id
  vpc_id                 = aws_vpc.main.id
  priority               = 101
  mutation_protection    = "DISABLED"
}

# ---------- Resolver query logging: every DNS question asked in the VPC ----------
resource "aws_cloudwatch_log_group" "queries" {
  name              = "/${local.name_prefix}/resolver-query-logs"
  retention_in_days = var.query_log_retention_days
}

resource "aws_route53_resolver_query_log_config" "main" {
  name            = "${local.name_prefix}-query-logs"
  destination_arn = aws_cloudwatch_log_group.queries.arn
}

resource "aws_route53_resolver_query_log_config_association" "vpc" {
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.main.id
  resource_id                  = aws_vpc.main.id
}

resource "aws_cloudwatch_query_definition" "firewall_hits" {
  name            = "${local.name_prefix}/firewall-hits"
  log_group_names = [aws_cloudwatch_log_group.queries.name]
  query_string    = <<-EOT
    fields @timestamp, query_name, query_type, rcode, firewall_rule_action, srcaddr
    | filter ispresent(firewall_rule_action)
    | sort @timestamp desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "top_queries" {
  name            = "${local.name_prefix}/top-queried-names"
  log_group_names = [aws_cloudwatch_log_group.queries.name]
  query_string    = <<-EOT
    stats count(*) as lookups by query_name
    | sort lookups desc
    | limit 20
  EOT
}
