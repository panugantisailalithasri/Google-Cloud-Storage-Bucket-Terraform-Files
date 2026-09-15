# DSO instances use SSL_MODE=ALLOW_UNENCRYPTED_AND_ENCRYPTED on private VPC IPs.
#checkov:skip=CKV_GCP_6:Private IP only; DSO allows unencrypted in-VPC connections
resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection
  encryption_key_name = var.kms_key_name

  settings {
    tier              = var.tier
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    availability_type = "ZONAL"
    user_labels       = var.labels

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.pitr_enabled
      transaction_log_retention_days = 7
    }

    insights_config {
      query_insights_enabled = var.query_insights
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.private_network
      ssl_mode        = var.ssl_mode
    }

    dynamic "database_flags" {
      for_each = var.iam_authentication ? [1] : []

      content {
        name  = "cloudsql.iam_authentication"
        value = "on"
      }
    }
  }
}

resource "google_sql_database" "this" {
  for_each = toset(var.databases)

  project  = var.project_id
  name     = each.value
  instance = google_sql_database_instance.this.name
}
