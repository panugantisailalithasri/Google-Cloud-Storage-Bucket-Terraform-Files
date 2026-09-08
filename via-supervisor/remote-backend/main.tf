# Creates the dedicated GCS remote-backend bucket for this agent.
# Run once before terraform init in the parent folder.
# via-supervisor → gs://via-supervisor-tfstate
# A second agent folder uses the same gcs-bucket module → gs://<product>-tfstate

locals {
  bucket_name = "${var.product_name}-tfstate"
}

resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
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

  depends_on = [google_project_service.storage]
}
