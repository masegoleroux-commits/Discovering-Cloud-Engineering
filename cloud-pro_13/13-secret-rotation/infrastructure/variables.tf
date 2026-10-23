variable "rotation_days" {
  description = "Rotate the API key automatically every N days (the guide also rotates on demand)"
  type        = number
  default     = 7
  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "rotation_days must be between 1 and 365."
  }
}

variable "client_cache_seconds" {
  description = "How long the client app caches the key before re-reading it"
  type        = number
  default     = 300
}

variable "log_retention_days" {
  description = "How long Lambda logs are kept"
  type        = number
  default     = 1
}
