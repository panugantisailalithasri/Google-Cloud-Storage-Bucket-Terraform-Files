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

variable "command" {
  description = "Optional container command (image ENTRYPOINT override). Null keeps the image command."
  type        = list(string)
  default     = null
}

variable "args" {
  description = "Optional container args (image CMD override). Null keeps the image args."
  type        = list(string)
  default     = null
}

variable "cloud_sql_instances" {
  description = "Cloud SQL instance connection names to mount at /cloudsql."
  type        = list(string)
  default     = []
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
  description = "Identities granted roles/run.invoker. Use allow_unauthenticated for allUsers."
  type        = list(string)
  default     = []
}

variable "allow_unauthenticated" {
  description = "Grant roles/run.invoker to allUsers. Only for services that authenticate in-app (for example Cognito)."
  type        = bool
  default     = false
}

variable "concurrency" {
  description = "Max concurrent requests per instance."
  type        = number
  default     = 80
}

variable "vpc_network" {
  description = "VPC network for Direct VPC egress. Empty skips VPC attachment."
  type        = string
  default     = ""
}

variable "vpc_subnet" {
  description = "Subnetwork for Direct VPC egress."
  type        = string
  default     = ""
}

variable "vpc_egress" {
  description = "Cloud Run VPC egress. PRIVATE_RANGES_ONLY or ALL_TRAFFIC."
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
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
