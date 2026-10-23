data "aws_availability_zones" "available" {
  state = "available"
}

# Note what is NOT here: no internet gateway, no NAT, no public IPs.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # both are required for interface endpoint private DNS
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "private" {
  for_each          = { a = 0, b = 1 }
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 1)
  availability_zone = data.aws_availability_zones.available.names[(var.az_index + each.value) % length(data.aws_availability_zones.available.names)]
  tags              = { Name = "${local.name_prefix}-private-${each.key}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "endpoints" {
  name        = "${local.name_prefix}-endpoints-sg"
  description = "HTTPS from inside the VPC to the interface endpoints"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.endpoints.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_security_group" "workload" {
  name        = "${local.name_prefix}-workload-sg"
  description = "No inbound. Outbound HTTPS only to the VPC endpoints and the S3/DynamoDB prefix lists."
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "workload_to_interface_endpoints" {
  security_group_id = aws_security_group.workload.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "workload_to_gateway_endpoints" {
  for_each          = { s3 = aws_vpc_endpoint.s3.prefix_list_id, dynamodb = aws_vpc_endpoint.dynamodb.prefix_list_id }
  security_group_id = aws_security_group.workload.id
  description       = "HTTPS to ${each.key} through its gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = each.value
}
