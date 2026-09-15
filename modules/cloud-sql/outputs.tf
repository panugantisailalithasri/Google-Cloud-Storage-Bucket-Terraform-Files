output "name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Instance connection name (project:region:instance)."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP address assigned by GCP."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_names" {
  description = "Created database names."
  value       = [for db in google_sql_database.this : db.name]
}
