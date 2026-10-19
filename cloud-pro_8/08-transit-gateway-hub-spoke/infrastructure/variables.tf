variable "vpc_cidrs" {
  description = "One VPC per role. Non-overlapping ranges are required for VPC peering."
  type        = map(string)
  default = {
    shared = "10.100.0.0/16"
    app    = "10.101.0.0/16"
    data   = "10.102.0.0/16"
  }
  validation {
    condition     = alltrue([for k in ["shared", "app", "data"] : contains(keys(var.vpc_cidrs), k)])
    error_message = "vpc_cidrs must contain the keys shared, app and data."
  }
}

variable "allow_app_to_data" {
  description = "Segmentation switch. false = app and data can only reach shared services. true = app and data can also reach each other."
  type        = bool
  default     = false
}

variable "test_port" {
  description = "TCP port the reachability tests check (443 = HTTPS)"
  type        = number
  default     = 443
}
