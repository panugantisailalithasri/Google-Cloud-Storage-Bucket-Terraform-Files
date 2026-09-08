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

    backup_configuration {
      enabled                        = var.backup_enabled
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
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
