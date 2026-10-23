variable "vpc_cidr" {
  description = "Address range for the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet that holds the NAT instance"
  type        = string
  default     = "10.30.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet for the app server (no public IPs)"
  type        = string
  default     = "10.30.11.0/24"
}

variable "nat_instance_type" {
  description = "Size for the NAT instance. t4g.micro (ARM, Graviton) is cheapest; t3.micro (x86) is the backup if AWS has no t4g capacity. All four allowed sizes are Free Tier eligible on the AWS free plan."
  type        = string
  default     = "t4g.micro"
  validation {
    condition     = contains(["t4g.micro", "t4g.small", "t3.micro", "t3.small"], var.nat_instance_type)
    error_message = "Use a Free Tier eligible size (t4g.micro, t4g.small, t3.micro or t3.small): my account is on the AWS free plan."
  }
}

variable "app_instance_type" {
  description = "Size for the private app server (same choices as nat_instance_type)"
  type        = string
  default     = "t4g.micro"
  validation {
    condition     = contains(["t4g.micro", "t4g.small", "t3.micro", "t3.small"], var.app_instance_type)
    error_message = "Use a Free Tier eligible size (t4g.micro, t4g.small, t3.micro or t3.small): my account is on the AWS free plan."
  }
}

variable "flow_log_retention_days" {
  description = "How long VPC Flow Logs are kept"
  type        = number
  default     = 1
}

variable "alert_email" {
  description = "Email for the NAT health alarm (confirm the subscription)"
  type        = string
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
