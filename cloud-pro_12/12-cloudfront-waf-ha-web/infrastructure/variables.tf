variable "vpc_cidr" {
  description = "Address range for the VPC"
  type        = string
  default     = "10.60.0.0/16"
}

variable "instance_type" {
  description = "Size for the web servers. t4g.micro (ARM, Graviton) is cheapest; t3.micro (x86) is the backup if AWS has no t4g capacity. All four allowed sizes are Free Tier eligible on the AWS free plan."
  type        = string
  default     = "t4g.micro"
  validation {
    condition     = contains(["t4g.micro", "t4g.small", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Use a Free Tier eligible size (t4g.micro, t4g.small, t3.micro or t3.small): my account is on the AWS free plan."
  }
}

variable "az_index" {
  description = "Which pair of Availability Zones to use: 0 = eu-north-1a + 1b, 1 = 1b + 1c, 2 = 1c + 1a. Change it if AWS reports InsufficientInstanceCapacity in one zone."
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 2], var.az_index)
    error_message = "az_index must be 0, 1 or 2 (eu-north-1 has three Availability Zones)."
  }
}

variable "asg_min" {
  description = "Minimum web servers (2 = one per Availability Zone)"
  type        = number
  default     = 2
}

variable "asg_max" {
  description = "Maximum web servers when scaling out"
  type        = number
  default     = 4
  validation {
    condition     = var.asg_max <= 4
    error_message = "Keep asg_max at 4 or less to control cost."
  }
}

variable "cpu_target_percent" {
  description = "Target tracking: add servers when average CPU goes above this"
  type        = number
  default     = 50
}

variable "rate_limit_per_minute" {
  description = "Requests per IP per minute before AWS WAF blocks that IP"
  type        = number
  default     = 100
}

variable "enable_cloudfront" {
  description = "Put CloudFront in front of the ALB. Set false if your account blocks CloudFront (the ALB is then public, still behind WAF)."
  type        = bool
  default     = true
}

variable "waf_scope" {
  description = "REGIONAL = WAF on the ALB in your region (works with single-region accounts). CLOUDFRONT = WAF on CloudFront (needs us-east-1)."
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.waf_scope)
    error_message = "waf_scope must be REGIONAL or CLOUDFRONT."
  }
}
