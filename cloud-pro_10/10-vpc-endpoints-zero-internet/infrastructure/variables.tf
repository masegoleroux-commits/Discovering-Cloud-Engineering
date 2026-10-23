variable "vpc_cidr" {
  description = "Address range for the VPC (no internet gateway is ever attached)"
  type        = string
  default     = "10.40.0.0/16"
}

variable "instance_type" {
  description = "Size for the private workload. t4g.micro (ARM, Graviton) is cheapest; t3.micro (x86) is the backup if AWS has no t4g capacity. All four allowed sizes are Free Tier eligible on the AWS free plan."
  type        = string
  default     = "t4g.micro"
  validation {
    condition     = contains(["t4g.micro", "t4g.small", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Use a Free Tier eligible size (t4g.micro, t4g.small, t3.micro or t3.small): my account is on the AWS free plan."
  }
}

variable "interface_endpoint_services" {
  description = "AWS services reached through private interface endpoints. These three are what Session Manager and Run Command need."
  type        = list(string)
  default     = ["ssm", "ssmmessages", "ec2messages"]
}

variable "az_index" {
  description = "Which Availability Zone to use: 0 = eu-north-1a, 1 = eu-north-1b, 2 = eu-north-1c. Change it if AWS reports InsufficientInstanceCapacity for your instance type in one zone."
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 2], var.az_index)
    error_message = "az_index must be 0, 1 or 2 (eu-north-1 has three Availability Zones)."
  }
}
