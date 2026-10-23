# Latest Amazon Linux 2023 in the right CPU architecture for the chosen size:
# t4g = ARM (Graviton, arm64), t3 = Intel/AMD (x86_64). The SSM agent is pre-installed.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  workload_ami = startswith(var.instance_type, "t4g.") ? data.aws_ssm_parameter.al2023_arm64.value : data.aws_ssm_parameter.al2023_x86_64.value
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

resource "aws_iam_role" "workload" {
  name               = "${local.name_prefix}-workload-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.workload.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM deliberately ALSO allows the outside bucket: if the instance still can't read it,
# that proves the VPC endpoint policy, not IAM, is doing the blocking.
resource "aws_iam_role_policy" "workload_data" {
  name = "${local.name_prefix}-workload-data"
  role = aws_iam_role.workload.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*", aws_s3_bucket.outside.arn, "${aws_s3_bucket.outside.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.events.arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "workload" {
  name = "${local.name_prefix}-workload-profile"
  role = aws_iam_role.workload.name
}

resource "aws_instance" "workload" {
  ami                         = local.workload_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private["a"].id
  associate_public_ip_address = false # no internet path at all
  vpc_security_group_ids      = [aws_security_group.workload.id]
  iam_instance_profile        = aws_iam_instance_profile.workload.name

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

  tags = { Name = "${local.name_prefix}-workload" }

  # The SSM agent can only register once its private endpoints exist.
  depends_on = [aws_vpc_endpoint.interface]
}
