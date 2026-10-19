variable "vpc_cidr" {
  description = "Address range for the whole VPC"
  type        = string
  default     = "10.20.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnets; the key is the Availability Zone suffix"
  type        = map(string)
  default     = { a = "10.20.1.0/24", b = "10.20.2.0/24" }
}

variable "private_subnet_cidrs" {
  description = "Private subnets with no internet route (reserved for a data tier)"
  type        = map(string)
  default     = { a = "10.20.11.0/24", b = "10.20.12.0/24" }
}

variable "instance_type" {
  description = "EC2 size. Limited to small burstable types to keep costs low (t3.micro is Free Tier eligible)."
  type        = string
  default     = "t3.micro"
  validation {
    condition = contains([
      "t3.nano", "t3.micro", "t3.small", "t3.medium",
      "t3a.nano", "t3a.micro", "t3a.small", "t3a.medium",
    ], var.instance_type)
    error_message = "Use a t3/t3a size from nano to medium (Stockholm has no t2 instances)."
  }
}

variable "root_volume_size_gb" {
  description = "Root disk size in GB (Free Tier covers up to 30 GB of EBS)"
  type        = number
  default     = 8
  validation {
    condition     = var.root_volume_size_gb >= 8 && var.root_volume_size_gb <= 30
    error_message = "Root volume must be between 8 and 30 GB."
  }
}

variable "allowed_http_cidrs" {
  description = "Who may reach port 80. Set to [\"<your-ip>/32\"] to lock it down."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cpu_alarm_threshold" {
  description = "CPU percentage that triggers the alarm"
  type        = number
  default     = 70
}

variable "alert_email" {
  description = "Email address for alarm notifications (you must confirm the subscription)"
  type        = string
}

# --- Emergency fallback only: use if Session Manager can't connect ---
variable "enable_ssh_fallback" {
  description = "Open port 22 to ssh_allowed_cidr. Leave false unless Session Manager fails."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Your public IP as /32, used only when enable_ssh_fallback is true"
  type        = string
  default     = "127.0.0.1/32"
  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "ssh_allowed_cidr must be a single IP range, never 0.0.0.0/0."
  }
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name, used only when enable_ssh_fallback is true"
  type        = string
  default     = ""
}

# --- Use these if your account blocks the automatic lookups (e.g. an Organization SCP) ---
variable "availability_zones" {
  description = "Two AZ names, e.g. [\"eu-north-1a\", \"eu-north-1b\"]. Leave empty to look them up automatically."
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 2
    error_message = "Give exactly two Availability Zones, or leave the list empty."
  }
}

variable "ami_id" {
  description = "Ubuntu 24.04 AMI ID, e.g. \"ami-0abc...\". Leave empty to look up the latest one automatically."
  type        = string
  default     = ""
}
