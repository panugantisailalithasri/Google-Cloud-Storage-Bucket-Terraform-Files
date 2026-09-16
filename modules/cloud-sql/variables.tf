variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cloud SQL instance name."
  type        = string
}

variable "region" {
  description = "Instance region."
  type        = string
}

variable "database_version" {
  description = "Database version, for example POSTGRES_18."
  type        = string
}

variable "edition" {
  description = "Cloud SQL edition: ENTERPRISE or ENTERPRISE_PLUS."
  type        = string
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.edition)
    error_message = "edition must be ENTERPRISE or ENTERPRISE_PLUS."
  }
}

variable "tier" {
  description = "Machine tier. Use db-custom-N-MB for ENTERPRISE; db-perf-optimized-N-* for ENTERPRISE_PLUS."
  type        = string
}

variable "disk_size_gb" {
  description = "Starting PD-SSD size in GB. Autoresize is enabled."
  type        = number
}

variable "private_network" {
  description = "VPC self link or name for private IP."
  type        = string
}

variable "ssl_mode" {
  description = "Cloud SQL SSL mode."
  type        = string
  default     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
}

variable "databases" {
  description = "Database names to create on the instance."
  type        = list(string)
}

variable "iam_authentication" {
  description = "Enable Cloud SQL IAM database authentication."
  type        = bool
  default     = true
}

variable "pitr_enabled" {
  description = "Enable point-in-time recovery."
  type        = bool
  default     = true
}

variable "query_insights" {
  description = "Enable Query Insights."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Protect the instance from terraform destroy and GCP deletion."
  type        = bool
  default     = true
}

variable "kms_key_name" {
  description = "Optional CMEK key. Google-managed encryption when null."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to the instance."
  type        = map(string)
  default     = {}
}
