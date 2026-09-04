# Creates the dedicated GCS remote-backend bucket for this agent.
# Run once before terraform init in the parent folder.
# Example: via-supervisor → gs://via-supervisor-tfstate

locals {
  bucket_name = "${var.product_name}-tfstate"
}

module "state_bucket" {
  source = "../../modules/gcs-bucket"

  project_id         = var.project_id
  name               = local.bucket_name
  location           = var.region
  storage_class      = "STANDARD"
  force_destroy      = false
  versioning_enabled = true
  labels = {
    product    = var.product_name
    purpose    = "terraform-remote-backend"
    managed_by = "terraform"
  }
}
