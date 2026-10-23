# Latest Amazon Linux 2023 in the right CPU architecture for the chosen size:
# t4g = ARM (Graviton, arm64), t3 = Intel/AMD (x86_64).
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  web_ami = startswith(var.instance_type, "t4g.") ? data.aws_ssm_parameter.al2023_arm64.value : data.aws_ssm_parameter.al2023_x86_64.value
}

resource "aws_launch_template" "web" {
  name_prefix            = "${local.name_prefix}-web-"
  image_id               = local.web_ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = base64encode(file("${path.module}/templates/web_user_data.sh"))

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
      volume_size = 8
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.asg_min
  max_size                  = var.asg_max
  desired_capacity          = var.asg_min
  vpc_zone_identifier       = [for s in aws_subnet.private : s.id]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB" # replace servers the load balancer says are unhealthy
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  depends_on = [aws_vpc_endpoint.s3]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}
