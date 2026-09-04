variable "project_id" {
  description = "GCP project that owns this agent's Terraform state bucket."
  type        = string
  default     = "freyr-ai"
}

variable "region" {
  description = "Location for the state bucket."
  type        = string
  default     = "us-east1"
}

variable "product_name" {
  description = "Agent / microservice name. The state bucket is <product_name>-tfstate."
  type        = string
  default     = "via-supervisor"
}
