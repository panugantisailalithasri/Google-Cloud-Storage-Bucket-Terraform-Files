resource "google_storage_bucket" "this" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.location
  storage_class               = var.storage_class
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = var.uniform_bucket_level_access
  public_access_prevention    = var.public_access_prevention
  labels                      = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_age_days != null && var.versioning_enabled ? [var.lifecycle_age_days] : []

    content {
      condition {
        days_since_noncurrent_time = lifecycle_rule.value
      }

      action {
        type = "Delete"
      }
    }
  }
}
