variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secrets" {
  description = "Map of secret id => accessors. Payloads are passed separately in secret_payloads so for_each keys stay non-sensitive."
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

variable "secret_payloads" {
  description = "Map of secret id => payload. Keys must match var.secrets. Values come from ADO, not git."
  type        = map(string)
  sensitive   = true
  default     = {}
}
