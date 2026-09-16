terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: this stack creates the remote-backend bucket
  # that the agent stack then uses.
  backend "local" {}
}
