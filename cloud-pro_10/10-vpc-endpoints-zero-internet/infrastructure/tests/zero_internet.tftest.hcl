# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"] }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:eu-north-1:123456789012:table/events" }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = { id = "vpce-0123456789abcdef0", prefix_list_id = "pl-0123456789abcdef0" }
  }
}

override_resource {
  target = aws_s3_bucket.data
  values = { arn = "arn:aws:s3:::zero-dev-data-123456789012", id = "zero-dev-data-123456789012" }
}

override_resource {
  target = aws_s3_bucket.outside
  values = { arn = "arn:aws:s3:::zero-dev-outside-123456789012", id = "zero-dev-outside-123456789012" }
}

# Fixed values, so these tests never depend on your own terraform.tfvars
variables {
  owner         = "test"
  aws_region    = "eu-north-1"
  az_index      = 0
  instance_type = "t4g.micro"
}

# TC-10-T01: through the S3 endpoint, only the project's own bucket can be used
run "s3_endpoint_allows_only_data_bucket" {
  command = apply
  assert {
    condition = alltrue([
      for r in flatten([jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Resource]) :
      startswith(r, "arn:aws:s3:::zero-dev-data-123456789012")
    ])
    error_message = "The S3 endpoint policy must only name the data bucket."
  }
  assert {
    condition     = !contains(flatten([jsondecode(aws_vpc_endpoint.s3.policy).Statement[0].Action]), "s3:*")
    error_message = "The S3 endpoint policy must not allow s3:*."
  }
}

# TC-10-T02: IAM deliberately allows the outside bucket, so the endpoint policy is what blocks it
run "iam_also_allows_outside_bucket" {
  command = apply
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.workload_data.policy).Statement[0].Resource, "arn:aws:s3:::zero-dev-outside-123456789012/*")
    error_message = "The defence-in-depth test needs IAM to allow the outside bucket."
  }
}

# TC-10-T03: confidential objects are refused unless the request comes through the endpoint
run "bucket_policy_requires_vpce" {
  command = apply
  assert {
    condition     = jsondecode(aws_s3_bucket_policy.data.policy).Statement[0].Effect == "Deny"
    error_message = "The bucket policy must be a Deny."
  }
  assert {
    condition     = jsondecode(aws_s3_bucket_policy.data.policy).Statement[0].Condition.StringNotEquals["aws:SourceVpce"] == "vpce-0123456789abcdef0"
    error_message = "The Deny must apply to every request not coming through the S3 endpoint."
  }
}

# TC-10-T04: the DynamoDB endpoint only reaches the events table
run "dynamodb_endpoint_allows_only_events_table" {
  command = apply
  assert {
    condition     = jsondecode(aws_vpc_endpoint.dynamodb.policy).Statement[0].Resource == "arn:aws:dynamodb:eu-north-1:123456789012:table/events"
    error_message = "The DynamoDB endpoint policy must only name the events table."
  }
}

# TC-10-T05: the three interface endpoints Session Manager needs, with private DNS
run "ssm_interface_endpoints_with_private_dns" {
  command = apply
  assert {
    condition     = toset(keys(aws_vpc_endpoint.interface)) == toset(["ssm", "ssmmessages", "ec2messages"])
    error_message = "Expected the ssm, ssmmessages and ec2messages endpoints."
  }
  assert {
    condition     = alltrue([for e in aws_vpc_endpoint.interface : e.private_dns_enabled])
    error_message = "Interface endpoints need private DNS so normal AWS names resolve privately."
  }
}

# TC-10-T06: the workload has no public IP and no route to the internet in its security group
run "workload_has_no_internet_path" {
  command = apply
  assert {
    condition     = aws_instance.workload.associate_public_ip_address == false
    error_message = "The workload must not get a public IP."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.workload_to_interface_endpoints.cidr_ipv4 == "10.40.0.0/16"
    error_message = "Workload egress must stay inside the VPC (plus the S3/DynamoDB prefix lists)."
  }
  assert {
    condition     = aws_instance.workload.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }
}

# TC-10-T07: data at rest is protected
run "data_bucket_blocks_public_access" {
  command = apply
  assert {
    condition     = aws_s3_bucket_public_access_block.data.block_public_policy && aws_s3_bucket_public_access_block.data.restrict_public_buckets
    error_message = "The data bucket must block public access."
  }
}

# TC-10-T08: sizes the free plan blocks are rejected (negative test)
run "rejects_non_free_tier_size" {
  command = plan
  variables {
    instance_type = "t4g.nano"
  }
  expect_failures = [var.instance_type]
}

# TC-10-T09: the backup size t3.micro (x86) gets the x86 image instead of the ARM one
run "t3_backup_uses_x86_image" {
  command = apply
  variables {
    instance_type = "t3.micro"
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
    condition     = aws_instance.workload.ami == "ami-0x86x86x86x86x86"
    error_message = "A t3 (x86) workload must use the x86_64 Amazon Linux image."
  }
}
