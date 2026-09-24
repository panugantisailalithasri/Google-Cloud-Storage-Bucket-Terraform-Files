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
  description = "Product or agent name used as the first segment of every resource name. Pipeline productName overrides this."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.product_name))
    error_message = "product_name must be 3-20 lowercase characters (letters, digits, hyphens) and start with a letter."
  }
}

variable "environment" {
  description = "Environment name used as the second segment of every resource name (productname-ENVname-Resourcename)."
  type        = string

  validation {
    condition     = contains(["dev", "prod", "dso", "devsecops", "production"], var.environment)
    error_message = "environment must be dev, prod, dso, devsecops, or production."
  }
}

variable "runtime_service_account_email" {
  description = "Existing GCP service account email used as the Cloud Run runtime identity and granted access to buckets and secrets. No new SA is created."
  type        = string
}

variable "image_tag" {
  description = "Docker image tag deployed to all Cloud Run services in this stack. Passed by the pipeline as -var=image_tag=<tag>. Must not be 'latest'."
  type        = string

  validation {
    condition     = var.image_tag != "latest" && var.image_tag != ""
    error_message = "image_tag must be a specific tag or digest. 'latest' and empty string are not allowed."
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
  description = "Cloud Run VPC egress setting. Used only when cloud_run_direct_vpc is true."
  type        = string
}

variable "cloud_run_direct_vpc" {
  description = "Attach Cloud Run to the VPC. False uses Cloud Run default internet (Vertex/PAC) and Cloud SQL via /cloudsql. SQL instances still use vpc_network for private IP."
  type        = bool
}

variable "buckets" {
  description = "GCS buckets. Name is composed as product-env-resource. runtime_service_account_email is automatically granted runtime_role."
  type = map(object({
    product_name       = optional(string)
    resource_name      = optional(string)
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
}

variable "secrets" {
  description = "Secret Manager secrets. secret_id is composed as product-env-resource. runtime_service_account_email is automatically granted secretAccessor."
  type = map(object({
    product_name  = optional(string)
    resource_name = optional(string)
  }))
}

variable "secret_payloads" {
  description = "Optional map of secret handle => payload. Pipeline injects ADO variable-group values; leave empty in tfvars. Never commit real secret data."
  type        = map(string)
  sensitive   = true
}

variable "gcs_config_objects" {
  description = "JSON objects Terraform writes into application buckets. Key matches a cloud_run_services handle."
  type = map(object({
    bucket_key  = string
    object_name = string
  }))
}

variable "config_object_payloads" {
  description = "Optional map of gcs_config_objects handle => JSON body. Empty uses the stack-generated common.json. Never commit real secret data."
  type        = map(string)
  sensitive   = true
}

variable "sql_instances" {
  description = "Cloud SQL instances. Instance name is composed as product-env-resource. Set name_override only for pre-existing instances whose GCP name cannot be changed."
  type = map(object({
    product_name          = optional(string)
    resource_name         = optional(string)
    name_override         = optional(string)
    edition               = optional(string, "ENTERPRISE")
    database_version      = string
    tier                  = string
    disk_size_gb          = number
    databases             = list(string)
    iam_authentication    = bool
    pitr_enabled          = bool
    query_insights        = bool
    deletion_protection   = bool
    ssl_mode              = string
    kms_key_name          = optional(string)
    app_user              = optional(string)
    connection_secret_key = optional(string)
  }))
}

variable "cloud_run_services" {
  description = "Cloud Run services. Service name is composed as product-env-resource. All services share runtime_service_account_email."
  type = map(object({
    product_name          = optional(string)
    resource_name         = optional(string)
    image_repository      = string
    port                  = number
    cpu                   = string
    memory                = string
    min_instances         = number
    max_instances         = number
    concurrency           = number
    timeout_seconds       = number
    env_vars              = map(string)
    secret_env_keys       = map(string)
    extra_secret_env_vars = optional(map(string), {})
    config_bucket_key     = optional(string)
    config_bucket_name    = optional(string)
    session_secret_key    = optional(string)
    memory_secret_key     = optional(string)
    command               = optional(list(string))
    args                  = optional(list(string))
    ingress               = string
    allow_unauthenticated = bool
    extra_invoker_members = list(string)
    deletion_protection   = bool
  }))
}

variable "gemini_enterprise" {
  description = "Gemini Enterprise identifiers written into the GCS config JSON."
  type = object({
    application_id     = string
    via_agent_id       = string
    agent_display_name = string
  })
}

variable "observability" {
  description = "Tracing settings written into the GCS config JSON."
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
