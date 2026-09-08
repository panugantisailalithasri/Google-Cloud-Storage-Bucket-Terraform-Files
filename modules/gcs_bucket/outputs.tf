output "name" {
  description = "Bucket name."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "Bucket gs:// URL."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "Bucket self link."
  value       = google_storage_bucket.this.self_link
}
