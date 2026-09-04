variable "project_id" {
  description = "GCP project that owns this agent's Terraform state bucket. Set in terraform.tfvars."
  type        = string
}

variable "region" {
  description = "Location for the state bucket. Set in terraform.tfvars."
  type        = string
}

variable "product_name" {
  description = "Agent / microservice name. The state bucket is <product_name>-tfstate. Set in terraform.tfvars."
  type        = string
}
