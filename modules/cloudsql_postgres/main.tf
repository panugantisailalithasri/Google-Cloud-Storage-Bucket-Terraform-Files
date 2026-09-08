resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

data "google_compute_network" "private" {
  name    = var.private_network_name
  project = coalesce(var.network_project_id, var.project_id)
}

resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  depends_on = [
    google_project_service.sqladmin,
    google_project_service.servicenetworking,
  ]

  settings {
    tier                        = var.tier
    edition                     = var.edition
    availability_type           = var.availability_type
    disk_type                   = var.disk_type
    disk_size                   = var.disk_size
    disk_autoresize             = var.disk_autoresize
    deletion_protection_enabled = var.deletion_protection_enabled
    user_labels                 = var.labels

    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = data.google_compute_network.private.self_link
      ssl_mode                                      = var.ssl_mode
      enable_private_path_for_google_cloud_services = var.enable_private_path_for_google_cloud_services

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          value = authorized_networks.value
        }
      }
    }

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
  }
}
