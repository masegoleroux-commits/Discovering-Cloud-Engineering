data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Two zones for high availability. az_index shifts which two: 0 = 1a + 1b, 1 = 1b + 1c, 2 = 1c + 1a
  az_names = data.aws_availability_zones.available.names
  azs = {
    a = local.az_names[(var.az_index) % length(local.az_names)]
    b = local.az_names[(var.az_index + 1) % length(local.az_names)]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  for_each          = local.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.key == "a" ? 1 : 2)
  availability_zone = each.value
  tags              = { Name = "${local.name_prefix}-public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each          = local.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.key == "a" ? 11 : 12)
  availability_zone = each.value
  tags              = { Name = "${local.name_prefix}-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

# Private subnets: no internet route. The S3 gateway endpoint below is enough for
# Amazon Linux 2023 to install packages, because its repositories are hosted in S3.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${local.name_prefix}-s3-gateway" }
}

# ---------- Security groups: CloudFront → ALB → web servers, nothing else ----------
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.enable_cloudfront ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "HTTP from CloudFront origin-facing addresses (or the internet if CloudFront is off)"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  count             = var.enable_cloudfront ? 1 : 0
  security_group_id = aws_security_group.alb.id
  description       = "CloudFront origin-facing servers only"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
}

# Without CloudFront, the ALB itself is the public entry point (still behind the regional WAF).
resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  count             = var.enable_cloudfront ? 0 : 1
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP (only when CloudFront is disabled)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "HTTP only from the load balancer; HTTPS out only to S3 for packages"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_s3" {
  security_group_id = aws_security_group.web.id
  description       = "Package repositories in S3, via the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}
