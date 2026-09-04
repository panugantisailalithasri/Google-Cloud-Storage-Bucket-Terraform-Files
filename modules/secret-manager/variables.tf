variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secrets" {
  description = "Map of secret key => accessors. Secret values are not managed here; add versions out of band or via CI secrets."
  type = map(object({
    accessors = optional(list(string), [])
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
