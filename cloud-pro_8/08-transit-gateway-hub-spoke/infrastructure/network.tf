data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Two subnets per VPC (one per AZ), keyed "app-0", "app-1", ...
  subnets = merge([
    for vpc, cidr in var.vpc_cidrs : {
      for i, az in local.azs : "${vpc}-${i}" => {
        vpc  = vpc
        az   = az
        cidr = cidrsubnet(cidr, 8, i + 1)
      }
    }
  ]...)

  # For each VPC, the CIDRs of the other two VPCs (used by the probe security groups)
  other_cidrs = {
    for vpc in keys(var.vpc_cidrs) : vpc => [for other, cidr in var.vpc_cidrs : cidr if other != vpc]
  }
  vpc_routes = merge([
    for vpc, cidrs in local.other_cidrs : {
      for cidr in cidrs : "${vpc}->${cidr}" => { vpc = vpc, cidr = cidr }
    }
  ]...)
}

resource "aws_vpc" "this" {
  for_each             = var.vpc_cidrs
  cidr_block           = each.value
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-${each.key}-vpc", Role = each.key }
}

resource "aws_subnet" "private" {
  for_each          = local.subnets
  vpc_id            = aws_vpc.this[each.value.vpc].id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "${local.name_prefix}-${each.key}", Role = each.value.vpc }
}

resource "aws_route_table" "this" {
  for_each = var.vpc_cidrs
  vpc_id   = aws_vpc.this[each.key].id
  tags     = { Name = "${local.name_prefix}-${each.key}-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.this[each.value.vpc].id
}

# Routes between VPCs live in peering.tf (aws_route.peering).
