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

variable "private_network_name" {
  description = "Existing VPC network name used for private IP."
  type        = string
}

variable "network_project_id" {
  description = "Optional project ID that owns the VPC network."
  type        = string
  default     = null
}

variable "database_version" {
  description = "Cloud SQL database version."
  type        = string
}

variable "edition" {
  description = "Cloud SQL edition."
  type        = string
}

variable "tier" {
  description = "Machine tier."
  type        = string
}

variable "availability_type" {
  description = "Cloud SQL availability type."
  type        = string
}

variable "disk_type" {
  description = "Disk type."
  type        = string
}

variable "disk_size" {
  description = "Disk size in GB."
  type        = number
}

variable "disk_autoresize" {
  description = "Whether disk autoresize is enabled."
  type        = bool
}

variable "ipv4_enabled" {
  description = "Whether public IPv4 is enabled."
  type        = bool
}

variable "ssl_mode" {
  description = "Client SSL mode."
  type        = string
}

variable "enable_private_path_for_google_cloud_services" {
  description = "Whether private path for Google Cloud services is enabled."
  type        = bool
}

variable "authorized_networks" {
  description = "Authorized CIDR ranges used with public IP."
  type        = list(string)
}

variable "database_flags" {
  description = "Optional database flags."
  type = list(object({
    name  = string
    value = string
  }))
}

variable "labels" {
  description = "Labels for the Cloud SQL instance."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Whether Terraform is prevented from deleting the instance."
  type        = bool
}

variable "deletion_protection_enabled" {
  description = "Whether Cloud SQL deletion protection is enabled at the API level."
  type        = bool
}
