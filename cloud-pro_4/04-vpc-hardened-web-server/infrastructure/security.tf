resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "HTTP in from allowed CIDRs; all outbound for updates, SSM and CloudWatch"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name_prefix}-web-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = toset(var.allowed_http_cidrs)
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

# Created ONLY if enable_ssh_fallback = true, and only from your own IP.
resource "aws_vpc_security_group_ingress_rule" "ssh_fallback" {
  count             = var.enable_ssh_fallback ? 1 : 0
  security_group_id = aws_security_group.web.id
  description       = "SSH fallback from one IP (Session Manager unavailable)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
