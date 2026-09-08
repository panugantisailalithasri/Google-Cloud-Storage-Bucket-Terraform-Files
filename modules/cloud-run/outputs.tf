output "name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.this.name
}

output "uri" {
  description = "HTTPS URI of the service."
  value       = google_cloud_run_v2_service.this.uri
}

output "id" {
  description = "Fully qualified service ID."
  value       = google_cloud_run_v2_service.this.id
}
