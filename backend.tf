terraform {
  backend "gcs" {
    bucket = "terraform-dev-agent"
    prefix = "google-cloud-storage-bucket"
  }
}
