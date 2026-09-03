output "bucket_name" {
  description = "Name of the created Cloud Storage bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "bucket_self_link" {
  description = "API self link for the bucket."
  value       = google_storage_bucket.this.self_link
}

output "location" {
  description = "Location of the bucket."
  value       = google_storage_bucket.this.location
}

output "storage_class" {
  description = "Default storage class of the bucket."
  value       = google_storage_bucket.this.storage_class
}
