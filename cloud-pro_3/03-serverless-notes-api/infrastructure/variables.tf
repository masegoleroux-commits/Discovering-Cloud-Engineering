variable "lambda_timeout_seconds" {
  description = "Lambda timeout. The sandbox caps it at 10 seconds."
  type        = number
  default     = 5
  validation {
    condition     = var.lambda_timeout_seconds <= 10
    error_message = "Sandbox limit: timeout must be 10 seconds or less."
  }
}

variable "lambda_memory_mb" {
  description = "Lambda memory. The sandbox caps it at 256 MB."
  type        = number
  default     = 128
  validation {
    condition     = var.lambda_memory_mb <= 256
    error_message = "Sandbox limit: memory must be 256 MB or less."
  }
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the function logs"
  type        = number
  default     = 1
}

variable "api_throttle_rate" {
  description = "Steady requests per second allowed through API Gateway"
  type        = number
  default     = 1
}

variable "api_throttle_burst" {
  description = "Short burst of requests allowed above the steady rate"
  type        = number
  default     = 5
}
