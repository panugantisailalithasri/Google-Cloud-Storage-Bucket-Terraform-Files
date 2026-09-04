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
  description = "Product or agent name (for example via-supervisor). Used in resource names and labels."
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
  description = "Map of bucket short names to settings. Bucket names are derived from project, product, env, and key."
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
}

variable "secret_keys" {
  description = "Short secret names. Terraform creates empty secrets; set versions in ADO/GCP, not in tfvars."
  type        = list(string)
  default     = []
}

variable "cloud_run" {
  description = "Cloud Run service settings. Set null to skip Cloud Run."
  type = object({
    image               = string
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
