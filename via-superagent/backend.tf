terraform {
  backend "gcs" {
    # Dedicated per-agent bucket and env prefix are supplied at init:
    #   -backend-config="bucket=<product_name>-tfstate"
    #   -backend-config="prefix=<environment>"
  }
}
