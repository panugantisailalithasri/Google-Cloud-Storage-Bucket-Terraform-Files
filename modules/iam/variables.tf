variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "account_id" {
  description = "Service account ID (6-30 characters, lowercase, must start with a letter)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6-30 characters, start with a letter, and use lowercase letters, digits, and hyphens."
  }
}

variable "display_name" {
  description = "Human-readable service account name."
  type        = string
}

variable "description" {
  description = "Service account description."
  type        = string
  default     = "Managed by Terraform"
}

variable "project_roles" {
  description = "Project-level roles granted to this service account. Primitive roles (owner/editor/viewer) are rejected."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for role in var.project_roles : !contains(["roles/owner", "roles/editor", "roles/viewer"], role)
    ])
    error_message = "Primitive roles (owner, editor, viewer) are not allowed. Use predefined or custom roles."
  }
}
