variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "af-south-1"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}
