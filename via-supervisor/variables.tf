variable "project_id" {
  description = "GCP project that owns the resources. Set in environments/*.tfvars."
  type        = string
}

variable "region" {
  description = "Default GCP region for provider and regional resources. Set in environments/*.tfvars."
  type        = string
}

variable "location" {
  description = "Cloud Storage location. Set in environments/*.tfvars (usually the same as region)."
  type        = string
}

variable "product_name" {
  description = "Product or agent name. Set in environments/*.tfvars. Combined as <product_name>-<environment>-<resource>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.product_name))
    error_message = "product_name must be 3-20 lowercase characters (letters, digits, hyphens) and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Set in environments/*.tfvars."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "labels" {
  description = "Extra labels merged onto every resource. Set in environments/*.tfvars."
  type        = map(string)
}

variable "enable_apis" {
  description = "Enable required GCP APIs in the project. Set in environments/*.tfvars."
  type        = bool
}

variable "runtime_sa_resource" {
  description = "Resource suffix for the runtime service account. Set in environments/*.tfvars (example: sa)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.runtime_sa_resource))
    error_message = "runtime_sa_resource must be lowercase letters, digits, and hyphens (example: sa)."
  }
}

variable "runtime_sa_roles" {
  description = "Project-level roles for the runtime service account. Set in environments/*.tfvars."
  type        = list(string)
}

variable "buckets" {
  description = "Map of resource suffixes to bucket settings. Set in environments/*.tfvars. Name is <product_name>-<environment>-<key>."
  type = map(object({
    storage_class      = string
    versioning_enabled = bool
    force_destroy      = bool
    lifecycle_age_days = number
    kms_key_name       = optional(string)
    runtime_role       = string
    extra_iam_members = list(object({
      role   = string
      member = string
    }))
  }))

  validation {
    condition = alltrue([
      for key in keys(var.buckets) : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", key))
    ])
    error_message = "Each buckets map key is the resource suffix only (example: bucket), and must be lowercase."
  }
}

variable "secret_keys" {
  description = "Resource suffixes for secrets. Set in environments/*.tfvars. Name is <product_name>-<environment>-<key>."
  type        = list(string)

  validation {
    condition = alltrue([
      for key in var.secret_keys : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", key))
    ])
    error_message = "Each secret key is the resource suffix only and must be lowercase (example: app-config)."
  }
}

variable "cloud_run" {
  description = "Cloud Run settings. Set null in environments/*.tfvars to skip Cloud Run."
  type = object({
    image               = string
    resource            = string
    port                = number
    cpu                 = string
    memory              = string
    min_instances       = number
    max_instances       = number
    timeout_seconds     = number
    env_vars            = map(string)
    secret_env_vars     = map(string)
    ingress             = string
    invoker_members     = list(string)
    deletion_protection = bool
  })
  nullable = true
}
