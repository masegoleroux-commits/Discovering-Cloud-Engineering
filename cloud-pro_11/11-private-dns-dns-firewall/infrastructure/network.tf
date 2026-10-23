data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # required for private hosted zones
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[(var.az_index) % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name_prefix}-public-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Free network interfaces that stand in for an internal app server and database.
resource "aws_network_interface" "service" {
  for_each    = toset(["app", "db"])
  subnet_id   = aws_subnet.public.id
  description = "Stand-in address for the internal ${each.key} service"
  tags        = { Name = "${local.name_prefix}-${each.key}-eni" }
}
