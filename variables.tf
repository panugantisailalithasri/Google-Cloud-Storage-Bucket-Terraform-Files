variable "project_id" {
  description = "GCP project ID where the bucket will be created."
  type        = string
}

variable "region" {
  description = "Default GCP region for the provider (does not have to match bucket location)."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally unique name for the Cloud Storage bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket names must be 3-63 characters, start and end with a letter or number, and use only lowercase letters, numbers, hyphens, underscores, and dots."
  }
}

variable "location" {
  description = "Bucket location. Use a region (us-central1), dual-region (NAM4), or multi-region (US, EU, ASIA)."
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Default storage class for objects in the bucket."
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      ["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"],
      var.storage_class
    )
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "force_destroy" {
  description = "If true, Terraform will delete all objects when destroying the bucket. Keep false in production."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable object versioning on the bucket."
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Public access prevention setting. Use 'enforced' to block public ACLs and IAM."
  type        = string
  default     = "enforced"

  validation {
    condition     = contains(["enforced", "inherited"], var.public_access_prevention)
    error_message = "public_access_prevention must be 'enforced' or 'inherited'."
  }
}

variable "uniform_bucket_level_access" {
  description = "Use uniform bucket-level IAM instead of object ACLs (recommended)."
  type        = bool
  default     = true
}

variable "soft_delete_retention_seconds" {
  description = "How long deleted objects are retained for recovery. Set 0 to disable soft delete. Default is 7 days."
  type        = number
  default     = 604800
}

variable "lifecycle_age_days" {
  description = "Delete noncurrent object versions after this many days. Set null to skip this rule."
  type        = number
  default     = 90
}

variable "labels" {
  description = "Labels to apply to the bucket."
  type        = map(string)
  default     = {}
}
