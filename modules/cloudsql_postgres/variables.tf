variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cloud SQL instance name."
  type        = string
}

variable "region" {
  description = "Cloud SQL region."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL database version."
  type        = string
  default     = "POSTGRES_18"
}

variable "edition" {
  description = "Cloud SQL edition."
  type        = string
  default     = "ENTERPRISE"
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "Cloud SQL availability type."
  type        = string
  default     = "ZONAL"
}

variable "disk_type" {
  description = "Cloud SQL disk type."
  type        = string
  default     = "PD_SSD"
}

variable "disk_size" {
  description = "Disk size in GB."
  type        = number
  default     = 10
}

variable "disk_autoresize" {
  description = "Whether disk autoresize is enabled."
  type        = bool
  default     = true
}

variable "private_network_name" {
  description = "Existing VPC network name for private IP."
  type        = string
}

variable "network_project_id" {
  description = "Optional project ID that owns the VPC network."
  type        = string
  default     = null
}

variable "ipv4_enabled" {
  description = "Whether public IPv4 is enabled."
  type        = bool
  default     = false
}

variable "ssl_mode" {
  description = "SSL mode for client connections."
  type        = string
  default     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
}

variable "enable_private_path_for_google_cloud_services" {
  description = "Whether Google private path is enabled."
  type        = bool
  default     = false
}

variable "authorized_networks" {
  description = "Authorized CIDR ranges for public IP access."
  type        = list(string)
  default     = []
}

variable "database_flags" {
  description = "Optional database flags."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "labels" {
  description = "Labels to apply to the instance."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Whether Terraform prevents deletion of the instance."
  type        = bool
  default     = false
}

variable "deletion_protection_enabled" {
  description = "Whether GCP-level deletion protection is enabled."
  type        = bool
  default     = false
}
