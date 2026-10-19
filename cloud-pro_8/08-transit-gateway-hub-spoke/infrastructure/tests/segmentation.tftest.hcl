# Offline test cases (no AWS account, no cost): run `terraform test` in infrastructure/.
# They prove the segmentation rules in the code before anything is deployed.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"] }
  }
}

variables {
  owner = "test"
}

# TC-08-T01: by default only the two hub peerings exist (no app <-> data)
run "only_hub_peerings_by_default" {
  command = plan
  assert {
    condition     = toset(keys(aws_vpc_peering_connection.this)) == toset(["shared-app", "shared-data"])
    error_message = "By default only shared-app and shared-data peerings may exist."
  }
}

# TC-08-T02: by default, routes exist only between shared and each spoke
run "routes_only_via_shared_by_default" {
  command = plan
  assert {
    condition     = toset(keys(aws_route.peering)) == toset(["shared->app", "app->shared", "shared->data", "data->shared"])
    error_message = "Without allow_app_to_data, app and data must have no route to each other."
  }
}

# TC-08-T03: every peering accepts itself (same account and region)
run "peerings_auto_accept" {
  command = plan
  assert {
    condition     = alltrue([for p in aws_vpc_peering_connection.this : p.auto_accept])
    error_message = "All peering connections must set auto_accept = true."
  }
}

# TC-08-T04: flipping the switch opens app <-> data
run "switch_opens_app_to_data" {
  command = plan
  variables {
    allow_app_to_data = true
  }
  assert {
    condition     = contains(keys(aws_vpc_peering_connection.this), "app-data")
    error_message = "With allow_app_to_data = true, an app-data peering must exist."
  }
  assert {
    condition     = contains(keys(aws_route.peering), "app->data") && contains(keys(aws_route.peering), "data->app")
    error_message = "With allow_app_to_data = true, app and data must route to each other."
  }
}

# TC-08-T05: two subnets per VPC, each in a different AZ
run "two_subnets_per_vpc_across_two_azs" {
  command = plan
  assert {
    condition     = length(aws_subnet.private) == 6
    error_message = "Expected 6 subnets (2 per VPC)."
  }
  assert {
    condition     = aws_subnet.private["app-0"].availability_zone != aws_subnet.private["app-1"].availability_zone
    error_message = "A VPC's two subnets must be in different AZs."
  }
}

# TC-08-T06: probe security groups never allow traffic from the internet
run "no_ingress_from_internet" {
  command = plan
  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.probe : r.cidr_ipv4 != "0.0.0.0/0"])
    error_message = "No probe ingress rule may allow 0.0.0.0/0."
  }
  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.probe : r.from_port == 443 && r.to_port == 443])
    error_message = "Probe ingress must allow only the test port (443)."
  }
}

# TC-08-T07: the three reachability questions exist
run "three_reachability_paths" {
  command = plan
  assert {
    condition     = toset(keys(aws_ec2_network_insights_path.test)) == toset(["app-to-shared", "data-to-shared", "app-to-data"])
    error_message = "Expected the three saved reachability paths."
  }
}

# TC-08-T08: a VPC map missing a role is rejected (negative test)
run "rejects_missing_vpc_role" {
  command = plan
  variables {
    vpc_cidrs = { shared = "10.100.0.0/16", app = "10.101.0.0/16" }
  }
  expect_failures = [var.vpc_cidrs]
}
