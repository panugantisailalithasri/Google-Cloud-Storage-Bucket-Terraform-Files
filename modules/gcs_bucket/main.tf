resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  depends_on = [google_project_service.storage]

  storage_class               = var.storage_class
  requester_pays              = var.requester_pays
  uniform_bucket_level_access = var.uniform_bucket_level_access
  public_access_prevention    = var.public_access_prevention
  force_destroy               = var.force_destroy
  labels                      = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_days * 24 * 60 * 60
  }
}

resource "google_storage_bucket_iam_member" "additional" {
  for_each = {
    for idx, binding in var.additional_iam_members :
    "${binding.role}:${binding.member}:${try(binding.condition.title, "unconditional")}:${idx}" => binding
  }

  bucket = google_storage_bucket.this.name
  role   = each.value.role
  member = each.value.member

  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [each.value.condition]
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}
