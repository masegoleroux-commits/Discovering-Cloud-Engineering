# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:eu-north-1:123456789012:threat-detect-dev-alerts" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:eu-north-1:123456789012:log-group:mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:eu-north-1:123456789012:function:mock" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:eu-north-1:123456789012:rule/mock" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::threat-detect-dev-trail-123456789012" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0canary0000000000" }
  }
}

# Fixed values, so these tests never depend on your own terraform.tfvars
variables {
  owner        = "test"
  alert_email  = "test@example.com"
  aws_region   = "eu-north-1"
  create_trail = true
}

# TC-15-T01: the security-group rule watches new inbound rules (the code then keeps only internet-wide ones)
run "sg_rule_watches_new_inbound_rules" {
  command = apply
  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.detect["sg-open-to-internet"].event_pattern).detail.eventName == ["AuthorizeSecurityGroupIngress"]
    error_message = "The rule must watch AuthorizeSecurityGroupIngress."
  }
  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.detect["sg-open-to-internet"].event_pattern).source == ["aws.ec2"]
    error_message = "The rule must only read EC2 events."
  }
}

# TC-15-T02: audit-trail tampering and removed bucket protection are watched too
run "trail_and_bucket_rules" {
  command = apply
  assert {
    condition     = toset(jsondecode(aws_cloudwatch_event_rule.detect["audit-logging-stopped"].event_pattern).detail.eventName) == toset(["StopLogging", "DeleteTrail"])
    error_message = "Stopping or deleting a trail must raise an alert."
  }
  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.detect["s3-public-block-removed"].event_pattern).detail.eventName == ["DeleteBucketPublicAccessBlock"]
    error_message = "Removing a bucket's Block Public Access must raise an alert."
  }
  assert {
    condition     = alltrue([for r in aws_cloudwatch_event_rule.detect : jsondecode(r.event_pattern)["detail-type"] == ["AWS API Call via CloudTrail"]])
    error_message = "Every rule must read CloudTrail API-call events."
  }
}

# TC-15-T03: every rule sends its events to both functions, and EventBridge may invoke them
run "every_rule_reaches_both_functions" {
  command = apply
  assert {
    condition     = length(aws_cloudwatch_event_target.fn) == 6 && length(aws_lambda_permission.events) == 6
    error_message = "3 rules x 2 functions = 6 targets and 6 invoke permissions."
  }
  assert {
    condition     = alltrue([for p in aws_lambda_permission.events : p.principal == "events.amazonaws.com"])
    error_message = "Only EventBridge may invoke the functions."
  }
}

# TC-15-T04: the responder can ONLY add the SecurityFinding tag to security groups, nothing destructive
run "responder_can_only_tag_security_groups" {
  command = apply
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.fn["responder"].policy).Statement :
      alltrue([for a in s.Action : contains(["ec2:CreateTags", "logs:CreateLogStream", "logs:PutLogEvents"], a)])
    ])
    error_message = "The responder may only tag and write its own logs (no RevokeSecurityGroupIngress, no Delete*)."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.fn["responder"].policy).Statement[0].Resource == "arn:aws:ec2:eu-north-1:123456789012:security-group/*"
    error_message = "Tagging must be limited to security groups."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.fn["responder"].policy).Statement[0].Condition["ForAllValues:StringEquals"]["aws:TagKeys"] == ["SecurityFinding"]
    error_message = "Only the SecurityFinding tag key may be written."
  }
}

# TC-15-T05: the formatter can only publish to this project's topic, and knows the test group
run "formatter_publishes_to_our_topic_only" {
  command = apply
  assert {
    condition     = jsondecode(aws_iam_role_policy.fn["formatter"].policy).Statement[0].Resource == aws_sns_topic.alerts.arn
    error_message = "The formatter must publish to this project's topic only."
  }
  assert {
    condition     = aws_lambda_function.fn["formatter"].environment[0].variables.TEST_SG_ID == aws_security_group.canary.id
    error_message = "The formatter must know the test group, so test alerts are labelled DELIBERATE TEST."
  }
}

# TC-15-T06: the trail is single-region, tamper-evident, and its bucket is private and encrypted
run "trail_is_private_and_tamper_evident" {
  command = apply
  assert {
    condition     = aws_cloudtrail.main[0].is_multi_region_trail == false && aws_cloudtrail.main[0].include_global_service_events == false
    error_message = "My account only allows eu-north-1, so the trail must be single-region."
  }
  assert {
    condition     = aws_cloudtrail.main[0].enable_log_file_validation == true
    error_message = "Log file validation must be on."
  }
  assert {
    condition = (
      aws_s3_bucket_public_access_block.trail[0].block_public_acls && aws_s3_bucket_public_access_block.trail[0].block_public_policy &&
      aws_s3_bucket_public_access_block.trail[0].ignore_public_acls && aws_s3_bucket_public_access_block.trail[0].restrict_public_buckets
    )
    error_message = "The log bucket must block all public access."
  }
  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.trail[0].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "The log bucket must be encrypted."
  }
}

# TC-15-T07: with an existing trail, no second trail or bucket is created
run "reuses_existing_trail" {
  command = apply
  variables {
    create_trail = false
  }
  assert {
    condition     = length(aws_cloudtrail.main) == 0 && length(aws_s3_bucket.trail) == 0 && output.trail_name == ""
    error_message = "create_trail = false must not create a trail or bucket."
  }
}

# TC-15-T08: the test security group starts with no inbound rules at all
run "test_group_starts_closed" {
  command = apply
  assert {
    condition     = length(aws_security_group.canary.ingress) == 0
    error_message = "The test group must have no inbound rules until run_tests.sh opens it."
  }
  assert {
    condition     = aws_security_group.canary.tags.Purpose == "deliberate-test"
    error_message = "The test group must be labelled as a deliberate-test resource."
  }
}

# TC-15-T09: a zone typed as the region, or a bad email, is refused (negative tests)
run "rejects_zone_as_region" {
  command = plan
  variables {
    aws_region = "eu-north-1b"
  }
  expect_failures = [var.aws_region]
}

run "rejects_bad_email" {
  command = plan
  variables {
    alert_email = "not-an-email"
  }
  expect_failures = [var.alert_email]
}
