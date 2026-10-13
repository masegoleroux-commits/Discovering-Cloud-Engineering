# Latest Ubuntu 24.04 LTS AMI, published by Canonical in SSM Parameter Store.
# Only looked up when you haven't set ami_id yourself.
data "aws_ssm_parameter" "ubuntu_ami" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "web" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.ubuntu_ami[0].value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public["a"].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.enable_ssh_fallback && var.ssh_key_name != "" ? var.ssh_key_name : null
  monitoring             = true # 1-minute metrics so the alarm reacts quickly

  credit_specification {
    cpu_credits = "standard" # Unlimited mode can add surprise charges when CPU runs high
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    access_log_group = aws_cloudwatch_log_group.nginx_access.name
    error_log_group  = aws_cloudwatch_log_group.nginx_error.name
    name_prefix      = local.name_prefix
  })
  user_data_replace_on_change = true

  tags = { Name = "${local.name_prefix}-web" }
}
