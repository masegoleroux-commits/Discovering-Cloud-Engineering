# Instead of paying for test instances, each VPC gets one network interface (ENI).
# ENIs are free, and VPC Reachability Analyzer can test paths between them.
resource "aws_security_group" "probe" {
  for_each    = var.vpc_cidrs
  name        = "${local.name_prefix}-${each.key}-probe-sg"
  description = "Allow the test port from the other VPCs"
  vpc_id      = aws_vpc.this[each.key].id
}

resource "aws_vpc_security_group_ingress_rule" "probe" {
  for_each          = local.vpc_routes
  security_group_id = aws_security_group.probe[each.value.vpc].id
  ip_protocol       = "tcp"
  from_port         = var.test_port
  to_port           = var.test_port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "probe" {
  for_each          = var.vpc_cidrs
  security_group_id = aws_security_group.probe[each.key].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_network_interface" "probe" {
  for_each        = var.vpc_cidrs
  subnet_id       = aws_subnet.private["${each.key}-0"].id
  security_groups = [aws_security_group.probe[each.key].id]
  description     = "Reachability test endpoint for the ${each.key} VPC"
  tags            = { Name = "${local.name_prefix}-${each.key}-probe" }
}

locals {
  test_paths = {
    "app-to-shared"  = { from = "app", to = "shared" }
    "data-to-shared" = { from = "data", to = "shared" }
    "app-to-data"    = { from = "app", to = "data" }
  }
}

# A "path" is just a saved question; running an analysis (scripts/run_analysis.sh) answers it.
resource "aws_ec2_network_insights_path" "test" {
  for_each         = local.test_paths
  source           = aws_network_interface.probe[each.value.from].id
  destination      = aws_network_interface.probe[each.value.to].id
  protocol         = "tcp"
  destination_port = var.test_port
  tags             = { Name = "${local.name_prefix}-${each.key}" }
}
