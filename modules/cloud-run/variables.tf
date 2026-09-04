variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cloud Run service name."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.name))
    error_message = "Cloud Run service names must be lowercase letters, numbers, and hyphens, and start with a letter."
  }
}

variable "location" {
  description = "Cloud Run region."
  type        = string
}

variable "image" {
  description = "Container image URI. Pin a tag or digest; :latest is not allowed."
  type        = string

  validation {
    condition     = var.image != "" && !endswith(var.image, ":latest")
    error_message = "Pin a specific image tag or digest. Do not use :latest."
  }
}

variable "service_account_email" {
  description = "Runtime service account email. Do not use the default Compute SA."
  type        = string
}

variable "port" {
  description = "Container listen port."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU limit (for example 1 or 2)."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit (for example 512Mi)."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instances."
  type        = number
  default     = 3
}

variable "timeout_seconds" {
  description = "Request timeout in seconds."
  type        = number
  default     = 60
}

variable "env_vars" {
  description = "Plain environment variables. Do not put secrets here."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Map of env var name => Secret Manager secret_id. Values are mounted at runtime."
  type        = map(string)
  default     = {}
}

variable "ingress" {
  description = "Ingress restriction."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "ingress must be a valid Cloud Run v2 ingress value."
  }
}

variable "invoker_members" {
  description = "Identities granted roles/run.invoker. Public principals are rejected."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for member in var.invoker_members : !contains(["allUsers", "allAuthenticatedUsers"], member)
    ])
    error_message = "Unauthenticated Cloud Run (allUsers / allAuthenticatedUsers) is not allowed."
  }
}

variable "deletion_protection" {
  description = "Prevent accidental terraform destroy of the service."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}
