variable "multi_region_trail" {
  description = "Record API calls in every region (attackers like regions you never use). The first copy of management events is free."
  type        = bool
  default     = true
}

variable "trail_log_retention_days" {
  description = "How long CloudWatch Logs keeps the trail events"
  type        = number
  default     = 1
}

variable "enable_config" {
  description = "Set false to skip AWS Config (it charges per recorded change); CloudTrail and alarms still deploy"
  type        = bool
  default     = true
}

variable "create_config_recorder" {
  description = "Set false if the account already has a Config recorder (only one is allowed per region)"
  type        = bool
  default     = true
}

variable "config_resource_types" {
  description = "Resource types the Config recorder tracks"
  type        = list(string)
  default = [
    "AWS::S3::Bucket",
    "AWS::EC2::SecurityGroup",
    "AWS::EC2::Volume",
    "AWS::EC2::Instance",
  ]
}

variable "alarm_period_seconds" {
  description = "Window each security alarm evaluates"
  type        = number
  default     = 300
}

variable "alert_email" {
  description = "Email for security alerts (confirm the subscription)"
  type        = string
}
