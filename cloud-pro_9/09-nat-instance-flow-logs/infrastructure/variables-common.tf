variable "aws_region" {
  description = "AWS region for every resource. Your account allows only eu-north-1 (Europe, Stockholm)."
  type        = string
  default     = "eu-north-1"
  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a region such as eu-north-1, not an Availability Zone such as eu-north-1b. To choose a zone, use az_index instead (projects 09-11)."
  }
}

variable "project_name" {
  description = "Short project identifier used in every resource name"
  type        = string
  default     = "nat-egress"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "owner" {
  description = "Your name or GitHub handle, written into resource tags"
  type        = string
}
