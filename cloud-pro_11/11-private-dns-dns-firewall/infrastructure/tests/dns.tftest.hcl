# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"] }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:eu-north-1:123456789012:log-group:mock" }
  }
}

variables {
  owner = "test"
}

# TC-11-T01: the zone is private (attached to the VPC), not public
run "zone_is_private" {
  command = apply
  assert {
    condition     = length(aws_route53_zone.private.vpc) == 1
    error_message = "The hosted zone must be associated with the VPC, which makes it private."
  }
}

# TC-11-T02: the three firewall actions, in the right order
run "firewall_rule_actions_and_priorities" {
  command = apply
  assert {
    condition     = aws_route53_resolver_firewall_rule.block.action == "BLOCK" && aws_route53_resolver_firewall_rule.block.block_response == "NXDOMAIN"
    error_message = "The first rule must block with NXDOMAIN."
  }
  assert {
    condition     = aws_route53_resolver_firewall_rule.sinkhole.block_response == "OVERRIDE" && aws_route53_resolver_firewall_rule.sinkhole.block_override_domain == "sinkhole.corp.internal."
    error_message = "The sinkhole rule must redirect to sinkhole.corp.internal."
  }
  assert {
    condition     = aws_route53_resolver_firewall_rule.alert.action == "ALERT"
    error_message = "The third rule must only alert."
  }
  assert {
    condition = (aws_route53_resolver_firewall_rule.block.priority < aws_route53_resolver_firewall_rule.sinkhole.priority
    && aws_route53_resolver_firewall_rule.sinkhole.priority < aws_route53_resolver_firewall_rule.alert.priority)
    error_message = "Rules must be evaluated block → sinkhole → alert."
  }
}

# TC-11-T03: the sinkhole points at a reserved documentation address, never a real server
run "sinkhole_uses_reserved_address" {
  command = apply
  assert {
    condition     = tolist(aws_route53_record.sinkhole.records)[0] == "192.0.2.1"
    error_message = "The sinkhole must point at 192.0.2.1 (RFC 5737 documentation range)."
  }
}

# TC-11-T04: every DNS question in the VPC is logged
run "query_logging_is_on" {
  command = apply
  assert {
    condition     = aws_route53_resolver_query_log_config.main.destination_arn == "arn:aws:logs:eu-north-1:123456789012:log-group:mock"
    error_message = "Query logs must go to the CloudWatch log group."
  }
}

# TC-11-T05: the test client has a Free Tier size and IMDSv2
run "client_is_free_tier_and_hardened" {
  command = apply
  assert {
    condition     = aws_instance.client.instance_type == "t4g.micro"
    error_message = "The client must use t4g.micro (Free Tier)."
  }
  assert {
    condition     = aws_instance.client.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }
}

# TC-11-T06: a zone name that could clash with the internet is rejected (negative test)
run "rejects_public_looking_zone_name" {
  command = plan
  variables {
    private_zone_name = "corp.co.za"
  }
  expect_failures = [var.private_zone_name]
}

# TC-11-T07: a domain without its trailing dot is rejected (negative test)
run "rejects_unqualified_domain" {
  command = plan
  variables {
    blocked_domains = ["doubleclick.net"]
  }
  expect_failures = [var.blocked_domains]
}
