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

output "app_user" {
  description = "Built-in app user name, or empty when none was created."
  value       = var.app_user
}

output "connection_json" {
  description = "JSON with private IP and app-user credentials for Secret Manager. Empty when app_user is unset."
  sensitive   = true
  value = var.app_user == "" ? "" : jsonencode({
    host            = google_sql_database_instance.this.private_ip_address
    port            = 5432
    user            = var.app_user
    username        = var.app_user
    password        = random_password.app[0].result
    database        = var.databases[0]
    databases       = var.databases
    instance        = google_sql_database_instance.this.name
    connection_name = google_sql_database_instance.this.connection_name
    unix_socket     = "/cloudsql/${google_sql_database_instance.this.connection_name}"
    private_ip      = google_sql_database_instance.this.private_ip_address
    sslmode         = "prefer"
  })
}
