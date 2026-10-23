variable "aws_region" {
  description = "AWS region for every resource. Your account allows only eu-north-1 (Europe, Stockholm)."
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Short project identifier used in every resource name"
  type        = string
  default     = "secret-rotation"
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
