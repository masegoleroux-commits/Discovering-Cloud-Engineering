# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:eu-north-1:123456789012:key/11111111-2222-3333-4444-555555555555", key_id = "11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::kms-demo-dev-data-123456789012" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:eu-north-1:123456789012:table/kms-demo-dev-records" }
  }
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:eu-north-1:123456789012:kms-demo-dev-events" }
  }
}

override_resource {
  target = aws_iam_role.key_admin
  values = { arn = "arn:aws:iam::123456789012:role/kms-demo-dev-key-admin" }
}

override_resource {
  target = aws_iam_role.app
  values = { arn = "arn:aws:iam::123456789012:role/kms-demo-dev-app" }
}

variables {
  owner = "test"
}

# TC-14-T01: key admins can manage the key but have NO action that reads or encrypts data
run "admins_cannot_use_the_key" {
  command = apply
  assert {
    condition = !anytrue([
      for a in local.key_policy.Statement[1].Action :
      anytrue([for bad in ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt", "kms:GenerateDataKey", "kms:*"] : startswith(a, bad)])
    ])
    error_message = "The key-admin statement must not contain Encrypt, Decrypt, ReEncrypt or GenerateDataKey."
  }
  assert {
    condition     = local.key_policy.Statement[1].Principal.AWS == "arn:aws:iam::123456789012:role/kms-demo-dev-key-admin"
    error_message = "The admin statement must name the key-admin role."
  }
}

# TC-14-T02: admins can't give themselves access (no CreateGrant, no PutKeyPolicy, no Create*)
run "admins_cannot_escalate" {
  command = apply
  assert {
    condition     = length(setintersection(toset(local.key_policy.Statement[1].Action), toset(["kms:CreateGrant", "kms:PutKeyPolicy", "kms:Create*", "kms:Put*"]))) == 0
    error_message = "Key admins must not be able to create grants or rewrite the key policy."
  }
}

# TC-14-T03: the app role can use the key and nothing else
run "users_can_only_use_the_key" {
  command = apply
  assert {
    condition     = contains(local.key_policy.Statement[2].Action, "kms:Decrypt") && contains(local.key_policy.Statement[2].Action, "kms:GenerateDataKey*")
    error_message = "The app role must be able to decrypt and generate data keys."
  }
  assert {
    condition     = !anytrue([for a in local.key_policy.Statement[2].Action : contains(["kms:ScheduleKeyDeletion", "kms:DisableKey", "kms:PutKeyPolicy"], a)])
    error_message = "The app role must not be able to manage the key."
  }
}

# TC-14-T04: the key rotates yearly and can't be deleted in one step
run "key_rotation_and_deletion_window" {
  command = apply
  assert {
    condition     = aws_kms_key.data.enable_key_rotation == true && aws_kms_key.data.deletion_window_in_days == 7
    error_message = "Automatic rotation must be on and deletion must wait 7 days."
  }
}

# TC-14-T05: S3, DynamoDB and SQS all use THIS key
run "all_three_services_use_the_key" {
  command = apply
  assert {
    condition = alltrue([for r in aws_s3_bucket_server_side_encryption_configuration.data.rule :
      r.bucket_key_enabled && alltrue([for d in r.apply_server_side_encryption_by_default : d.sse_algorithm == "aws:kms" && d.kms_master_key_id == "arn:aws:kms:eu-north-1:123456789012:key/11111111-2222-3333-4444-555555555555"])
    ])
    error_message = "The bucket must default to SSE-KMS with this key and an S3 Bucket Key."
  }
  assert {
    condition     = aws_dynamodb_table.records.server_side_encryption[0].kms_key_arn == "arn:aws:kms:eu-north-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    error_message = "The table must be encrypted with this key."
  }
  assert {
    condition     = aws_sqs_queue.events.kms_master_key_id == "arn:aws:kms:eu-north-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    error_message = "The queue must be encrypted with this key."
  }
}

# TC-14-T06: the deliberate test is valid: IAM DOES allow the admin to read the object
run "iam_lets_admin_read_so_kms_must_be_the_blocker" {
  command = apply
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.key_admin.policy).Statement[0].Action, "s3:GetObject")
    error_message = "The test needs IAM to allow s3:GetObject, so the denial proves KMS is the control."
  }
}

# TC-14-T08: the bucket refuses uploads under another encryption type or key, and plain HTTP
run "bucket_refuses_other_keys" {
  command = apply
  assert {
    condition = anytrue([
      for st in jsondecode(aws_s3_bucket_policy.data.policy).Statement :
      st.Effect == "Deny" && try(st.Condition.StringNotEqualsIfExists["s3:x-amz-server-side-encryption-aws-kms-key-id"], "") == "arn:aws:kms:eu-north-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    ])
    error_message = "Uploads naming a different KMS key must be denied."
  }
  assert {
    condition = anytrue([
      for st in jsondecode(aws_s3_bucket_policy.data.policy).Statement :
      st.Effect == "Deny" && try(st.Condition.Bool["aws:SecureTransport"], "") == "false"
    ])
    error_message = "Plain HTTP must be denied."
  }
}

# TC-14-T07: a deletion window AWS doesn't allow is rejected (negative test)
run "rejects_short_deletion_window" {
  command = plan
  variables {
    deletion_window_days = 1
  }
  expect_failures = [var.deletion_window_days]
}
