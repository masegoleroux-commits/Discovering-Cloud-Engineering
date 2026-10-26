variable "deletion_window_days" {
  description = "Waiting period before a deleted key is really gone (AWS allows 7-30 days)"
  type        = number
  default     = 7
  validation {
    condition     = var.deletion_window_days >= 7 && var.deletion_window_days <= 30
    error_message = "deletion_window_days must be between 7 and 30 (an AWS limit)."
  }
}
