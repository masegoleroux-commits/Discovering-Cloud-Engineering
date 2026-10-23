# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"] }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_ec2_managed_prefix_list" {
    defaults = { id = "pl-cloudfront0000" }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:eu-north-1:123456789012:loadbalancer/app/mock/1234567890abcdef", dns_name = "mock.eu-north-1.elb.amazonaws.com" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:eu-north-1:123456789012:targetgroup/mock/1234567890abcdef" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:eu-north-1:123456789012:listener/app/mock/1234567890abcdef/1234567890abcdef" }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:eu-north-1:123456789012:regional/webacl/mock/11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = { prefix_list_id = "pl-s30000000000" }
  }
}

mock_provider "aws" {
  alias = "us_east_1"
}

mock_provider "random" {}

# Fixed values, so these tests never depend on your own terraform.tfvars
variables {
  owner             = "test"
  aws_region        = "eu-north-1"
  az_index          = 0
  instance_type     = "t4g.micro"
  enable_cloudfront = true
  waf_scope         = "REGIONAL"
}

# TC-12-T01: by default WAF is regional, attached to the ALB, and nothing is created in us-east-1
run "waf_is_regional_by_default" {
  command = apply
  assert {
    condition     = length(module.waf_regional) == 1 && length(aws_wafv2_web_acl_association.alb) == 1
    error_message = "A regional WAF must be created and attached to the ALB."
  }
  assert {
    condition     = length(module.waf_global) == 0
    error_message = "No CloudFront-scope WAF (us-east-1) by default: my account blocks that region."
  }
}

# TC-12-T02: with CloudFront on, the ALB only accepts CloudFront's addresses
run "alb_only_accepts_cloudfront" {
  command = apply
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_from_cloudfront) == 1 && length(aws_vpc_security_group_ingress_rule.alb_from_internet) == 0
    error_message = "With CloudFront on, the ALB must allow only the CloudFront prefix list, not the internet."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_from_cloudfront[0].prefix_list_id == "pl-cloudfront0000"
    error_message = "The ALB rule must use the CloudFront origin-facing prefix list."
  }
}

# TC-12-T03: requests without the secret header get a 403; with it, they're forwarded
run "secret_header_required" {
  command = apply
  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "fixed-response" && aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "403"
    error_message = "The listener's default must be a 403 when CloudFront is on."
  }
  assert {
    condition     = anytrue([for c in aws_lb_listener_rule.from_cloudfront[0].condition : anytrue([for h in c.http_header : h.http_header_name == "X-Origin-Verify"])])
    error_message = "Only requests carrying the X-Origin-Verify header may be forwarded."
  }
}

# TC-12-T04: the web servers are only reachable from the ALB and only talk to S3
run "web_tier_is_locked_down" {
  command = apply
  assert {
    condition     = aws_vpc_security_group_egress_rule.web_to_s3.prefix_list_id == "pl-s30000000000" && aws_vpc_security_group_egress_rule.web_to_s3.from_port == 443
    error_message = "Web servers may only send HTTPS to the S3 prefix list."
  }
}

# TC-12-T05: high availability: at least 2 servers across 2 AZs, replaced on failed health checks
run "asg_is_highly_available" {
  command = apply
  assert {
    condition     = aws_autoscaling_group.web.min_size >= 2 && aws_autoscaling_group.web.health_check_type == "ELB"
    error_message = "The ASG needs at least 2 servers and ELB health checks."
  }
  assert {
    condition     = aws_subnet.private["a"].availability_zone != aws_subnet.private["b"].availability_zone
    error_message = "The private subnets must be in different AZs."
  }
}

# TC-12-T06: the load balancer drops malformed headers
run "alb_drops_invalid_headers" {
  command = apply
  assert {
    condition     = aws_lb.web.drop_invalid_header_fields == true
    error_message = "drop_invalid_header_fields must be on."
  }
}

# TC-12-T07: without CloudFront, the ALB becomes the public entry (still behind WAF)
run "cloudfront_off_makes_alb_public_behind_waf" {
  command = apply
  variables {
    enable_cloudfront = false
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_from_internet) == 1 && aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "With CloudFront off, the ALB must accept public traffic and forward it."
  }
  assert {
    condition     = length(aws_wafv2_web_acl_association.alb) == 1
    error_message = "The ALB must still be behind the WAF."
  }
}

# TC-12-T08: sizes the free plan blocks are rejected (negative test)
run "rejects_non_free_tier_size" {
  command = plan
  variables {
    instance_type = "t3.medium"
  }
  expect_failures = [var.instance_type]
}

# TC-12-T09: an unknown WAF scope is rejected (negative test)
run "rejects_unknown_waf_scope" {
  command = plan
  variables {
    waf_scope = "GLOBAL"
  }
  expect_failures = [var.waf_scope]
}

# TC-12-T10: the backup size t3.micro (x86) gets the x86 image, and az_index = 1 moves the servers to zones 1b + 1c
run "t3_backup_and_other_zones" {
  command = apply
  variables {
    instance_type = "t3.micro"
    az_index      = 1
  }
  override_data {
    target = data.aws_ssm_parameter.al2023_x86_64
    values = { value = "ami-0x86x86x86x86x86" }
  }
  override_data {
    target = data.aws_ssm_parameter.al2023_arm64
    values = { value = "ami-0a4ma4ma4ma4ma4m" }
  }
  assert {
    condition     = aws_launch_template.web.image_id == "ami-0x86x86x86x86x86"
    error_message = "A t3 (x86) web server must use the x86_64 Amazon Linux image."
  }
  assert {
    condition     = aws_subnet.private["a"].availability_zone == "eu-north-1b" && aws_subnet.private["b"].availability_zone == "eu-north-1c"
    error_message = "az_index = 1 must use eu-north-1b and eu-north-1c."
  }
}
