resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.key
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for binding in flatten([
      for secret_id, secret in var.secrets : [
        for member in secret.accessors : {
          key    = "${secret_id}/${member}"
          secret = secret_id
          member = member
        }
      ]
    ]) : binding.key => binding
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}

resource "google_secret_manager_secret_version" "this" {
  for_each = {
    for secret_id, secret in var.secrets : secret_id => secret
    if try(secret.secret_data, null) != null && try(secret.secret_data, "") != ""
  }

  secret      = google_secret_manager_secret.this[each.key].id
  secret_data = each.value.secret_data
}
