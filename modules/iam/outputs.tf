output "email" {
  description = "Service account email."
  value       = google_service_account.this.email
}

output "id" {
  description = "Service account ID."
  value       = google_service_account.this.id
}

output "member" {
  description = "IAM member string (serviceAccount:email)."
  value       = google_service_account.this.member
}

output "name" {
  description = "Fully qualified service account name."
  value       = google_service_account.this.name
}
