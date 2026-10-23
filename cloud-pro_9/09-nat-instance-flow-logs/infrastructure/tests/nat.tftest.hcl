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
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:eu-north-1:123456789012:mock" }
  }
}

variables {
  owner       = "test"
  alert_email = "test@example.com"
}

# TC-09-T01: the NAT instance can forward other machines' traffic
run "nat_source_dest_check_is_off" {
  command = apply
  assert {
    condition     = aws_instance.nat.source_dest_check == false
    error_message = "A NAT instance must have source/destination check turned off."
  }
}

# TC-09-T02: NAT rules in the start-up script translate only the private subnet
run "user_data_masquerades_private_subnet" {
  command = apply
  assert {
    condition     = strcontains(aws_instance.nat.user_data, "MASQUERADE") && strcontains(aws_instance.nat.user_data, "-s 10.30.11.0/24")
    error_message = "The NAT script must MASQUERADE traffic from the private subnet only."
  }
  assert {
    condition     = strcontains(aws_instance.nat.user_data, "net.ipv4.ip_forward = 1")
    error_message = "IP forwarding must be enabled."
  }
}

# TC-09-T03: the app server is private: no public IP, no inbound rules
run "app_server_is_private" {
  command = apply
  assert {
    condition     = aws_instance.app.associate_public_ip_address == false
    error_message = "The app server must not get a public IP."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.nat_from_private.cidr_ipv4 == "10.30.11.0/24"
    error_message = "The NAT may only accept traffic from the private subnet."
  }
}

# TC-09-T04: the private route table sends internet traffic to the NAT, not an internet gateway
run "private_default_route_uses_nat" {
  command = apply
  assert {
    condition     = alltrue([for r in aws_route_table.private.route : r.cidr_block == "0.0.0.0/0" && (r.gateway_id == null || r.gateway_id == "")])
    error_message = "The private default route must not point at an internet gateway."
  }
}

# TC-09-T05: both servers are hardened
run "instances_are_hardened" {
  command = apply
  assert {
    condition     = aws_instance.nat.metadata_options[0].http_tokens == "required" && aws_instance.app.metadata_options[0].http_tokens == "required"
    error_message = "Both instances must require IMDSv2."
  }
  assert {
    condition     = aws_instance.nat.root_block_device[0].encrypted && aws_instance.app.root_block_device[0].encrypted
    error_message = "Both root disks must be encrypted."
  }
}

# TC-09-T06: Flow Logs record everything, every minute
run "flow_logs_capture_all_traffic" {
  command = apply
  assert {
    condition     = aws_flow_log.vpc.traffic_type == "ALL" && aws_flow_log.vpc.max_aggregation_interval == 60
    error_message = "Flow Logs must capture ALL traffic at 1-minute aggregation."
  }
}

# TC-09-T07: the NAT host recovers itself
run "nat_auto_recovery_alarm" {
  command = apply
  assert {
    condition     = contains(aws_cloudwatch_metric_alarm.nat_system_check.alarm_actions, "arn:aws:automate:eu-north-1:ec2:recover")
    error_message = "The system check alarm must trigger EC2 auto-recovery."
  }
}

# TC-09-T08: sizes that the free plan blocks are rejected (negative test)
run "rejects_non_free_tier_size" {
  command = plan
  variables {
    nat_instance_type = "t4g.nano"
  }
  expect_failures = [var.nat_instance_type]
}

# TC-09-T09: the backup size t3.micro (x86) gets the x86 image, and t4g gets the ARM image
run "t3_backup_uses_x86_image" {
  command = apply
  variables {
    nat_instance_type = "t3.micro"
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
    condition     = aws_instance.nat.ami == "ami-0x86x86x86x86x86"
    error_message = "A t3 (x86) NAT instance must use the x86_64 Amazon Linux image."
  }
  assert {
    condition     = aws_instance.app.ami == "ami-0a4ma4ma4ma4ma4m"
    error_message = "The t4g (ARM) app server must still use the arm64 image."
  }
}
