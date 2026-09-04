resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  storage_class               = var.storage_class
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
  }

  dynamic "encryption" {
    for_each = var.kms_key_name != null ? [var.kms_key_name] : []

    content {
      default_kms_key_name = encryption.value
    }
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

resource "google_storage_bucket_iam_member" "this" {
  for_each = {
    for binding in var.iam_members : "${binding.role}/${binding.member}" => binding
  }

  bucket = google_storage_bucket.this.name
  role   = each.value.role
  member = each.value.member
}
