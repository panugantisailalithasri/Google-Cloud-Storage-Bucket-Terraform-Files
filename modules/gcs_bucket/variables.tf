variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "location" {
  description = "Bucket location, for example US-CENTRAL1."
  type        = string
}

variable "storage_class" {
  description = "Default storage class."
  type        = string
  default     = "STANDARD"
}

variable "requester_pays" {
  description = "Whether requester pays is enabled."
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Whether uniform bucket-level access is enabled."
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Public access prevention mode."
  type        = string
  default     = "inherited"
}

variable "versioning_enabled" {
  description = "Whether object versioning is enabled."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Soft-delete retention in days."
  type        = number
  default     = 7
}

variable "force_destroy" {
  description = "Whether Terraform may delete non-empty buckets."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the bucket."
  type        = map(string)
  default     = {}
}

variable "additional_iam_members" {
  description = "Optional extra IAM grants for the bucket."
  type = list(object({
    role   = string
    member = string
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = []
}
