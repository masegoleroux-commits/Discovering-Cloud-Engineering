# Offline tests (no AWS account needed): `terraform test` or `tofu test` in infrastructure/.
# They prove which IAM resources and lookups each ci_auth mode creates.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-aaaa1111", "subnet-bbbb2222"]
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }
  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:eu-north-1:123456789012:repository/container-app-dev-app"
      repository_url = "123456789012.dkr.ecr.eu-north-1.amazonaws.com/container-app-dev-app"
    }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:eu-north-1:123456789012:loadbalancer/app/mock/1234567890abcdef"
      dns_name = "mock-123.eu-north-1.elb.amazonaws.com"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-north-1:123456789012:targetgroup/mock/1234567890abcdef"
    }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:eu-north-1:123456789012:cluster/mock"
      id  = "arn:aws:ecs:eu-north-1:123456789012:cluster/mock"
    }
  }
  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:eu-north-1:123456789012:task-definition/mock:1"
    }
  }
  mock_resource "aws_ecs_service" {
    defaults = {
      id = "arn:aws:ecs:eu-north-1:123456789012:service/mock/mock"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-north-1:123456789012:log-group:/ecs/mock"
    }
  }
}

variables {
  owner = "test"
}

run "default_is_access_keys_with_no_oidc_lookups" {
  command = plan

  assert {
    condition     = var.ci_auth == "access_keys"
    error_message = "The default should be access_keys."
  }
  assert {
    condition     = length(data.aws_iam_openid_connect_provider.github) == 0
    error_message = "access_keys mode must NOT look up the OIDC provider (the account denies iam:ListOpenIDConnectProviders)."
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0 && length(aws_iam_role.github_deploy) == 0
    error_message = "access_keys mode must not create OIDC resources."
  }
  assert {
    condition     = length(aws_iam_user.github_ci) == 1
    error_message = "access_keys mode must create the CI user."
  }
}

run "leftover_create_provider_false_line_is_harmless" {
  command = plan
  variables {
    create_github_oidc_provider = false
  }
  assert {
    condition     = length(data.aws_iam_openid_connect_provider.github) == 0
    error_message = "An old create_github_oidc_provider = false line must not trigger the OIDC lookup in access_keys mode."
  }
}

run "oidc_mode_creates_provider_and_role" {
  command = plan
  variables {
    ci_auth = "oidc"
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1 && length(aws_iam_role.github_deploy) == 1
    error_message = "oidc mode must create the provider and the deploy role."
  }
  assert {
    condition     = length(aws_iam_user.github_ci) == 0
    error_message = "oidc mode must not create the CI user."
  }
}
