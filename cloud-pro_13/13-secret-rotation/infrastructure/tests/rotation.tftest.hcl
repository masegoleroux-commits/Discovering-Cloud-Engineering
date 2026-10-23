# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:eu-north-1:123456789012:secret:secret-rotation-dev/partner-api-key-AbCdEf" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:eu-north-1:123456789012:table/secret-rotation-dev-key-registry" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:eu-north-1:123456789012:log-group:mock" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:eu-north-1:123456789012:function:mock" }
  }
}

mock_provider "random" {}

variables {
  owner = "test"
}

# TC-13-T01: rotation runs on a schedule, but not immediately on deploy
run "rotation_schedule" {
  command = apply
  assert {
    condition     = aws_secretsmanager_secret_rotation.api_key.rotation_rules[0].automatically_after_days == 7
    error_message = "The key must rotate every 7 days by default."
  }
  assert {
    condition     = aws_secretsmanager_secret_rotation.api_key.rotate_immediately == false
    error_message = "Rotation must not fire on deploy; the guide rotates on demand."
  }
}

# TC-13-T02: only Secrets Manager, for this one secret, can run the rotation function
run "rotation_function_is_locked_to_the_secret" {
  command = apply
  assert {
    condition     = aws_lambda_permission.secretsmanager.principal == "secretsmanager.amazonaws.com"
    error_message = "Only Secrets Manager may invoke the rotation function."
  }
  assert {
    condition     = aws_lambda_permission.secretsmanager.source_arn == "arn:aws:secretsmanager:eu-north-1:123456789012:secret:secret-rotation-dev/partner-api-key-AbCdEf"
    error_message = "The permission must be limited to this secret."
  }
}

# TC-13-T03: the client can only READ the secret: it can never change or rotate it
run "client_is_read_only" {
  command = apply
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.fn["client"].policy).Statement :
      !anytrue([for a in s.Action : contains(["secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage", "secretsmanager:RotateSecret"], a)])
    ])
    error_message = "The client must not be able to write or rotate the secret."
  }
}

# TC-13-T04: the API can only read the registry
run "api_reads_registry_only" {
  command = apply
  assert {
    condition     = jsondecode(aws_iam_role_policy.fn["api"].policy).Statement[0].Action == ["dynamodb:GetItem"]
    error_message = "The API may only GetItem from the registry."
  }
}

# TC-13-T05: no function has a wildcard action, and "*" resources appear only where AWS requires it
run "no_wildcards" {
  command = apply
  assert {
    condition = alltrue(flatten([
      for k, p in aws_iam_role_policy.fn : [for s in jsondecode(p.policy).Statement : alltrue([for a in s.Action : !endswith(a, ":*") && a != "*"])]
    ]))
    error_message = "No IAM action may be a wildcard."
  }
  assert {
    condition = alltrue(flatten([
      for k, p in aws_iam_role_policy.fn : [for s in jsondecode(p.policy).Statement : s.Resource != "*" || s.Action == ["secretsmanager:GetRandomPassword"]]
    ]))
    error_message = "Only GetRandomPassword may use Resource \"*\" (it has no resource)."
  }
}

# TC-13-T06: the registry is encrypted and the secret is deleted immediately on teardown
run "registry_and_secret_settings" {
  command = apply
  assert {
    condition     = aws_dynamodb_table.registry.server_side_encryption[0].enabled
    error_message = "The registry must be encrypted at rest."
  }
  assert {
    condition     = aws_secretsmanager_secret.api_key.recovery_window_in_days == 0
    error_message = "Practice secret should be deleted immediately on destroy."
  }
}

# TC-13-T07: the registry stores a hash of the first key, never the key itself
run "registry_stores_hash_not_key" {
  command = apply
  assert {
    condition     = length(jsondecode(aws_dynamodb_table_item.initial_key.item).key_hash.S) == 64
    error_message = "The registry must store a 64-character SHA-256 hash."
  }
}

# TC-13-T08: an invalid rotation interval is rejected (negative test)
run "rejects_bad_rotation_interval" {
  command = plan
  variables {
    rotation_days = 0
  }
  expect_failures = [var.rotation_days]
}
