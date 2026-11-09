variable "alert_email" {
  description = "Where the readable alerts go (confirm the subscription, and check junk)"
  type        = string
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address."
  }
}

variable "create_trail" {
  description = "Create a CloudTrail trail (EventBridge needs one that is logging). Set false only if a trail is already logging in eu-north-1."
  type        = bool
  default     = true
}

variable "trail_log_days" {
  description = "How long the trail's log files are kept in S3"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "How long Lambda logs are kept"
  type        = number
  default     = 1
}
