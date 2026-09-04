terraform {
  backend "gcs" {
    bucket = "terraform-dev-agent"
    # prefix is supplied at init: PRODUCT_NAME/ENVIRONMENT
  }
}
