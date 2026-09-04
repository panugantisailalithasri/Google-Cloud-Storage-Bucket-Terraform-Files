variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.name))
    error_message = "Bucket names must be 3-63 characters, start and end with a letter or number, and use only lowercase letters, numbers, hyphens, underscores, and dots."
  }
}

variable "location" {
  description = "Bucket location (region, dual-region, or multi-region)."
  type        = string
}

variable "storage_class" {
  description = "Default storage class for objects."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "force_destroy" {
  description = "Allow Terraform to delete objects when destroying the bucket. Keep false in production."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable object versioning."
  type        = bool
  default     = true
}

variable "soft_delete_retention_seconds" {
  description = "Soft-delete retention in seconds. Set 0 to disable. Default is 7 days."
  type        = number
  default     = 604800
}

variable "lifecycle_age_days" {
  description = "Delete noncurrent object versions after this many days. Null skips the rule."
  type        = number
  default     = 90
}

variable "kms_key_name" {
  description = "Optional CMEK key (projects/.../cryptoKeys/...). Google-managed encryption is used when null."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the bucket."
  type        = map(string)
  default     = {}
}

variable "iam_members" {
  description = "IAM members granted on this bucket. Public principals are rejected."
  type = list(object({
    role   = string
    member = string
  }))
  default = []

  validation {
    condition = alltrue([
      for binding in var.iam_members : !contains(["allUsers", "allAuthenticatedUsers"], binding.member)
    ])
    error_message = "Public bucket IAM (allUsers / allAuthenticatedUsers) is not allowed."
  }
}
