variable "project_id" {
  description = "GCP project that owns the resources. Set in environments/*.tfvars."
  type        = string
}

variable "region" {
  description = "Default GCP region. Set in environments/*.tfvars."
  type        = string
}

variable "location" {
  description = "Cloud Storage location. Set in environments/*.tfvars."
  type        = string
}

variable "product_name" {
  description = "Product or agent name. Set in environments/*.tfvars."
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
    condition     = contains(["dev", "prod", "dso"], var.environment)
    error_message = "environment must be dev, prod, or dso."
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

variable "vpc_network" {
  description = "VPC network name or self link for Cloud Run Direct VPC egress and Cloud SQL private IP."
  type        = string
}

variable "vpc_subnet" {
  description = "Subnetwork name or self link for Cloud Run Direct VPC egress."
  type        = string
}

variable "vpc_egress" {
  description = "Cloud Run VPC egress setting."
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create. Key is a local handle used by buckets, secrets, and Cloud Run."
  type = map(object({
    account_id    = string
    display_name  = string
    description   = string
    project_roles = list(string)
  }))
}

variable "existing_runtime_service_account_email" {
  description = "Optional existing service account email to reuse instead of creating a new runtime service account."
  type        = string
  default     = null
}

variable "buckets" {
  description = "GCS buckets. Set name to the full bucket name. accessor_sa_keys references service_accounts keys."
  type = map(object({
    name               = string
    storage_class      = string
    versioning_enabled = bool
    force_destroy      = bool
    lifecycle_age_days = number
    kms_key_name       = optional(string)
    runtime_role       = string
    accessor_sa_keys   = list(string)
    extra_iam_members = list(object({
      role   = string
      member = string
    }))
  }))
}

variable "secrets" {
  description = "Secret Manager secrets. secret_id is the full secret name. accessor_sa_keys references service_accounts keys."
  type = map(object({
    secret_id        = string
    accessor_sa_keys = list(string)
  }))
}

variable "sql_instances" {
  description = "Cloud SQL instances keyed by a local handle."
  type = map(object({
    name                = string
    database_version    = string
    tier                = string
    disk_size_gb        = number
    databases           = list(string)
    iam_authentication  = bool
    pitr_enabled        = bool
    query_insights      = bool
    deletion_protection = bool
    ssl_mode            = string
    kms_key_name        = optional(string)
  }))
}

variable "cloud_run_services" {
  description = "Cloud Run services keyed by a local handle. sa_key references service_accounts."
  type = map(object({
    name                  = string
    image                 = string
    sa_key                = string
    port                  = number
    cpu                   = string
    memory                = string
    min_instances         = number
    max_instances         = number
    concurrency           = number
    timeout_seconds       = number
    env_vars              = map(string)
    secret_env_keys       = map(string)
    ingress               = string
    allow_unauthenticated = bool
    invoker_sa_keys       = list(string)
    extra_invoker_members = list(string)
    deletion_protection   = bool
  }))
}

variable "gemini_enterprise" {
  description = "Gemini Enterprise identifiers injected as Cloud Run env vars."
  type = object({
    application_id     = string
    via_agent_id       = string
    agent_display_name = string
  })
}

variable "observability" {
  description = "Tracing settings injected as Cloud Run env vars."
  type = object({
    via_tracing_enabled = bool
    traces_endpoint     = string
    pac_tracing_enabled = bool
  })
}

variable "pac_external" {
  description = "PAC MCP and graph endpoints."
  type = object({
    regulatory_mcp = string
    concept_graph  = string
  })
}

variable "cloudsql" {
  description = "Cloud SQL settings. Set null in environments/*.tfvars to skip Cloud SQL."
  type = object({
    name                                          = string
    region                                        = string
    database_version                              = string
    edition                                       = string
    tier                                          = string
    availability_type                             = string
    disk_type                                     = string
    disk_size                                     = number
    disk_autoresize                               = bool
    ipv4_enabled                                  = bool
    ssl_mode                                      = string
    enable_private_path_for_google_cloud_services = bool
    authorized_networks                           = list(string)
    backup_enabled                                = bool
    point_in_time_recovery_enabled                = bool
    database_flags = list(object({
      name  = string
      value = string
    }))
    deletion_protection         = bool
    deletion_protection_enabled = bool
  })
  nullable = true
}
