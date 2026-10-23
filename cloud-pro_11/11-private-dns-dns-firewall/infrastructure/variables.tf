variable "vpc_cidr" {
  description = "Address range for the VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "private_zone_name" {
  description = "Internal DNS name space, only resolvable inside the VPC"
  type        = string
  default     = "corp.internal"
  validation {
    condition     = endswith(var.private_zone_name, ".internal")
    error_message = "Use a name ending in .internal (reserved for private networks), so it can never clash with a real internet domain."
  }
}

variable "blocked_domains" {
  description = "Answered with NXDOMAIN (as if they don't exist). Trailing dot = fully qualified."
  type        = list(string)
  default     = ["doubleclick.net.", "*.doubleclick.net."]
  validation {
    condition     = alltrue([for d in var.blocked_domains : endswith(d, ".")])
    error_message = "Each domain must end with a dot (fully qualified), e.g. \"example.org.\"."
  }
}

variable "sinkholed_domains" {
  description = "Redirected to sinkhole.<private zone> instead of their real address"
  type        = list(string)
  default     = ["example.org.", "*.example.org."]
  validation {
    condition     = alltrue([for d in var.sinkholed_domains : endswith(d, ".")])
    error_message = "Each domain must end with a dot (fully qualified), e.g. \"example.org.\"."
  }
}

variable "alert_domains" {
  description = "Allowed to resolve, but every lookup is flagged in the query log"
  type        = list(string)
  default     = ["example.net.", "*.example.net."]
  validation {
    condition     = alltrue([for d in var.alert_domains : endswith(d, ".")])
    error_message = "Each domain must end with a dot (fully qualified), e.g. \"example.org.\"."
  }
}

variable "query_log_retention_days" {
  description = "How long DNS query logs are kept"
  type        = number
  default     = 1
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
