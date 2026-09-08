variable "project_id" {
  description = "GCP project ID for via-supervisor resources."
  type        = string
}

variable "environment" {
  description = "Environment name, defined per tfvars file."
  type        = string
}

variable "default_region" {
  description = "Default provider region for the stack."
  type        = string
  default     = "us-east4"
}

variable "vpc_name" {
  description = "Existing VPC name to use for resources that need VPC access."
  type        = string
}

variable "network_project_id" {
  description = "Optional project ID that owns the VPC network."
  type        = string
  default     = null
}

variable "common_labels" {
  description = "Common labels applied to all resources in this stack."
  type        = map(string)
  default     = {}
}

variable "gcs_bucket" {
  description = "GCS bucket configuration for via-supervisor."
  type = object({
    enabled                     = optional(bool, true)
    name                        = string
    location                    = optional(string, "US-CENTRAL1")
    storage_class               = optional(string, "STANDARD")
    requester_pays              = optional(bool, false)
    uniform_bucket_level_access = optional(bool, true)
    public_access_prevention    = optional(string, "inherited")
    versioning_enabled          = optional(bool, false)
    soft_delete_retention_days  = optional(number, 7)
    force_destroy               = optional(bool, false)
    labels                      = optional(map(string), {})
    additional_iam_members = optional(list(object({
      role   = string
      member = string
      condition = optional(object({
        title       = string
        description = optional(string)
        expression  = string
      }))
    })), [])
  })
}

variable "cloudsql" {
  description = "Cloud SQL configuration for via-supervisor."
  type = object({
    enabled                                       = optional(bool, true)
    name                                          = string
    region                                        = optional(string, "us-east4")
    database_version                              = optional(string, "POSTGRES_18")
    edition                                       = optional(string, "ENTERPRISE")
    tier                                          = optional(string, "db-custom-1-3840")
    availability_type                             = optional(string, "ZONAL")
    disk_type                                     = optional(string, "PD_SSD")
    disk_size                                     = optional(number, 10)
    disk_autoresize                               = optional(bool, true)
    ipv4_enabled                                  = optional(bool, false)
    ssl_mode                                      = optional(string, "ALLOW_UNENCRYPTED_AND_ENCRYPTED")
    enable_private_path_for_google_cloud_services = optional(bool, false)
    authorized_networks                           = optional(list(string), [])
    database_flags = optional(list(object({
      name  = string
      value = string
    })), [])
    labels                      = optional(map(string), {})
    deletion_protection         = optional(bool, false)
    deletion_protection_enabled = optional(bool, false)
  })
}
