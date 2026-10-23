# Latest Amazon Linux 2023, in the right CPU architecture for each size:
# t4g = ARM (Graviton, arm64), t3 = Intel/AMD (x86_64). The SSM agent is pre-installed.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  nat_ami = startswith(var.nat_instance_type, "t4g.") ? data.aws_ssm_parameter.al2023_arm64.value : data.aws_ssm_parameter.al2023_x86_64.value
  app_ami = startswith(var.app_instance_type, "t4g.") ? data.aws_ssm_parameter.al2023_arm64.value : data.aws_ssm_parameter.al2023_x86_64.value
}

resource "aws_instance" "nat" {
  ami                         = local.nat_ami
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  source_dest_check           = false # a router must forward packets that aren't addressed to itself

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

  user_data = templatefile("${path.module}/templates/nat_user_data.sh.tftpl", {
    private_cidr = var.private_subnet_cidr
  })
  user_data_replace_on_change = true

  tags = { Name = "${local.name_prefix}-nat" }
}

# A fixed public IP for all outbound traffic: partners can allow-list one address.
resource "aws_eip" "nat" {
  domain   = "vpc"
  instance = aws_instance.nat.id
  tags     = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_instance" "app" {
  ami                         = local.app_ami
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false # private server: its only way out is the NAT
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name

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

  tags = { Name = "${local.name_prefix}-app" }

  # The app needs the NAT working before its SSM agent can register.
  depends_on = [aws_route_table_association.private, aws_eip.nat]
}
