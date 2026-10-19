variable "aws_region" {
  description = "AWS region. The sandbox allows us-east-1, us-east-2 and us-west-2."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-2"], var.aws_region)
    error_message = "Sandbox allows only us-east-1, us-east-2 or us-west-2."
  }
}

variable "project_name" {
  description = "Short project identifier used in every resource name"
  type        = string
  default     = "notes-api"
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
