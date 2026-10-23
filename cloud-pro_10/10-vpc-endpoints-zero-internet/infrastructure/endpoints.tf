# ---------- Gateway endpoints (free): S3 and DynamoDB ----------
# They add prefix-list routes to the route table, so traffic to these services
# stays on the AWS network instead of needing the internet.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  # Data-exfiltration guard: through this endpoint, ONLY the project's data bucket can be used.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "OnlyTheProjectDataBucket"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource  = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
    }]
  })
  tags = { Name = "${local.name_prefix}-s3-gateway" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "OnlyTheProjectTable"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["dynamodb:PutItem", "dynamodb:GetItem"]
      Resource  = aws_dynamodb_table.events.arn
    }]
  })
  tags = { Name = "${local.name_prefix}-dynamodb-gateway" }
}

# ---------- Interface endpoints (paid, ~$0.01/hour each per AZ) ----------
# Each is a private network interface in the subnet. With private DNS on, the normal
# service names (ssm.<region>.amazonaws.com) resolve to these private IPs.
# Placed in ONE subnet to halve the cost; see ADR 0002.

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.interface_endpoint_services)
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private["a"].id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name_prefix}-${each.value}" }
}
