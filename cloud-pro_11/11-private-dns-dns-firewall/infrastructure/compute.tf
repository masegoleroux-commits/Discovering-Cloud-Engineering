data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "client" {
  name               = "${local.name_prefix}-client-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.client.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "client" {
  name = "${local.name_prefix}-client-profile"
  role = aws_iam_role.client.name
}

resource "aws_security_group" "client" {
  name        = "${local.name_prefix}-client-sg"
  description = "No inbound; outbound for SSM and package installs"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "client_out" {
  security_group_id = aws_security_group.client.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# A small client that asks DNS questions from inside the VPC.
resource "aws_instance" "client" {
  ami                    = data.aws_ssm_parameter.al2023_arm.value
  instance_type          = "t4g.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.client.id]
  iam_instance_profile   = aws_iam_instance_profile.client.name

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y bind-utils
  EOT

  tags = { Name = "${local.name_prefix}-client" }

  # Make sure the firewall and logging are live before the first query is asked.
  depends_on = [
    aws_route53_resolver_firewall_rule_group_association.vpc,
    aws_route53_resolver_query_log_config_association.vpc,
  ]
}
