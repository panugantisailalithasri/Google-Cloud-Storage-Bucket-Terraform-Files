variable "project_id" {
  description = "GCP project that owns the resources."
  type        = string
  default     = "freyr-ai"
}

variable "region" {
  description = "Default GCP region for provider and regional resources."
  type        = string
  default     = "us-east1"
}

variable "location" {
  description = "Cloud Storage location. Defaults to region."
  type        = string
  default     = null
}

variable "product_name" {
  description = "Product or agent name (for example via-supervisor). Combined with environment and a resource suffix: <product_name>-<environment>-<resource>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.product_name))
    error_message = "product_name must be 3-20 lowercase characters (letters, digits, hyphens) and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "labels" {
  description = "Extra labels merged onto every resource."
  type        = map(string)
  default     = {}
}

variable "enable_apis" {
  description = "Enable required GCP APIs in the project."
  type        = bool
  default     = true
}

variable "runtime_sa_resource" {
  description = "Resource suffix for the runtime service account. Final name is <product_name>-<environment>-<suffix> (example: via-supervisor-prod-sa)."
  type        = string
  default     = "sa"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.runtime_sa_resource))
    error_message = "runtime_sa_resource must be lowercase letters, digits, and hyphens (example: sa)."
  }
}

variable "runtime_sa_roles" {
  description = "Project-level roles for the product runtime service account."
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader",
  ]
}

variable "buckets" {
  description = "Map of resource suffixes to bucket settings. Name is <product_name>-<environment>-<key> (example key bucket → via-supervisor-prod-bucket). Pass only the suffix, not the full name."
  type = map(object({
    storage_class      = optional(string, "STANDARD")
    versioning_enabled = optional(bool, true)
    force_destroy      = optional(bool, false)
    lifecycle_age_days = optional(number, 90)
    kms_key_name       = optional(string)
    runtime_role       = optional(string, "roles/storage.objectUser")
    extra_iam_members = optional(list(object({
      role   = string
      member = string
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for key in keys(var.buckets) : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", key))
    ])
    error_message = "Each buckets map key is the resource suffix only (example: bucket), and must be lowercase."
  }
}

variable "secret_keys" {
  description = "Resource suffixes for secrets. Name is <product_name>-<environment>-<key> (example: via-supervisor-prod-app-config). Pass only the suffix. Terraform does not store secret values."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for key in var.secret_keys : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", key))
    ])
    error_message = "Each secret key is the resource suffix only and must be lowercase (example: app-config)."
  }
}

variable "cloud_run" {
  description = "Cloud Run service settings. Set null to skip Cloud Run. Service name is <product_name>-<environment>-<resource> (default resource: run)."
  type = object({
    image               = string
    resource            = optional(string, "run")
    port                = optional(number, 8080)
    cpu                 = optional(string, "1")
    memory              = optional(string, "512Mi")
    min_instances       = optional(number, 0)
    max_instances       = optional(number, 3)
    timeout_seconds     = optional(number, 60)
    env_vars            = optional(map(string), {})
    secret_env_vars     = optional(map(string), {})
    ingress             = optional(string, "INGRESS_TRAFFIC_INTERNAL_ONLY")
    invoker_members     = optional(list(string), [])
    deletion_protection = optional(bool, true)
  })
  default = null
}
