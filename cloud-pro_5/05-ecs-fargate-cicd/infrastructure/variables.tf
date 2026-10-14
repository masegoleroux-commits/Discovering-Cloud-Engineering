variable "image_tag" {
  description = "Image tag used for the very first deploy only; the pipeline handles later releases"
  type        = string
  default     = "bootstrap"
}

variable "container_port" {
  description = "Port uvicorn listens on inside the container"
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "Fargate CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate memory in MB (256 CPU allows 512-2048)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Running tasks. Each Fargate task costs money per hour, and deploys briefly double the count."
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 2
    error_message = "Keep desired_count at 1 or 2 to control cost."
  }
}

variable "health_check_path" {
  description = "Path the load balancer checks"
  type        = string
  default     = "/health"
}

variable "github_repository" {
  description = "GitHub repo allowed to deploy, as owner/name"
  type        = string
  default     = "masegoleroux-commits/Discovering-Cloud-Engineering"
}

variable "github_branch" {
  description = "Only workflows running on this branch may deploy"
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Set false if your account already has the GitHub OIDC provider (only one is allowed)"
  type        = bool
  default     = true
}

variable "ci_auth" {
  description = "How GitHub Actions signs in to AWS: access_keys (default: my account's organisation blocks OIDC providers) or oidc (no stored keys, preferred where allowed)"
  type        = string
  default     = "access_keys"
  validation {
    condition     = contains(["oidc", "access_keys"], var.ci_auth)
    error_message = "ci_auth must be oidc or access_keys."
  }
}
