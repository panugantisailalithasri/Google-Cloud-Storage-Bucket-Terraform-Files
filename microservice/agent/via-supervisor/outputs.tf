output "gcs_bucket_name" {
  description = "GCS bucket name for via-supervisor."
  value       = try(module.gcs_bucket[0].name, null)
}

output "gcs_bucket_url" {
  description = "GCS bucket URL for via-supervisor."
  value       = try(module.gcs_bucket[0].url, null)
}

output "cloudsql_instance_name" {
  description = "Cloud SQL instance name."
  value       = try(module.cloudsql[0].name, null)
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name."
  value       = try(module.cloudsql[0].connection_name, null)
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address."
  value       = try(module.cloudsql[0].private_ip_address, null)
}
