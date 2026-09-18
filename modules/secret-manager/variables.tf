variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secrets" {
  description = "Map of secret id => accessors and optional payload. When secret_data is set, a Secret Manager version is created (payload comes from ADO, not git)."
  type = map(object({
    accessors   = optional(list(string), [])
    secret_data = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for _, secret in var.secrets : [
        for member in secret.accessors : !contains(["allUsers", "allAuthenticatedUsers"], member)
      ]
    ]))
    error_message = "Public secret accessors (allUsers / allAuthenticatedUsers) are not allowed."
  }
}

variable "labels" {
  description = "Labels applied to every secret."
  type        = map(string)
  default     = {}
}
