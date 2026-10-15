variable "upload_prefix" {
  description = "Only objects under this prefix start the pipeline"
  type        = string
  default     = "incoming/"
}

variable "max_file_bytes" {
  description = "Largest file accepted (1 MB)"
  type        = number
  default     = 1048576
}

variable "max_rows" {
  description = "Most rows accepted per file, so each load finishes well inside the Lambda timeout"
  type        = number
  default     = 1000
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout. Capped at 10 seconds as a guardrail: these functions should finish in well under 1 second."
  type        = number
  default     = 10
  validation {
    condition     = var.lambda_timeout_seconds <= 10
    error_message = "Guardrail: keep the timeout at 10 seconds or less."
  }
}

variable "lambda_memory_mb" {
  description = "Lambda memory. Capped at 256 MB as a cost guardrail."
  type        = number
  default     = 256
  validation {
    condition     = var.lambda_memory_mb <= 256
    error_message = "Guardrail: keep memory at 256 MB or less."
  }
}

variable "task_max_attempts" {
  description = "Step Functions retries per task for temporary AWS errors"
  type        = number
  default     = 2
  validation {
    condition     = var.task_max_attempts <= 3
    error_message = "Keep retries low so a failing file can never loop."
  }
}

variable "alert_email" {
  description = "Email for success and rejection notifications (confirm the subscription)"
  type        = string
}
