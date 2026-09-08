output "product_name" {
  description = "Product name used for this stack."
  value       = var.product_name
}

output "environment" {
  description = "Environment used for this stack."
  value       = var.environment
}

output "resource_names" {
  description = "Names following <product_name>-<environment>-<resource>."
  value = {
    service_account = local.sa_name
    cloud_run       = var.cloud_run == null ? null : local.cloud_run_name
    cloudsql        = var.cloudsql == null ? null : local.cloudsql.name
    buckets         = { for key, bucket in module.buckets : key => bucket.name }
    secrets         = local.secret_ids
  }
}

output "runtime_service_account" {
  description = "Runtime service account email."
  value       = module.runtime_sa.email
}

output "bucket_names" {
  description = "Created bucket names keyed by short name."
  value       = { for key, bucket in module.buckets : key => bucket.name }
}

output "bucket_urls" {
  description = "gs:// URLs keyed by short name."
  value       = { for key, bucket in module.buckets : key => bucket.url }
}

output "secret_ids" {
  description = "Secret Manager IDs keyed by short name."
  value       = local.secret_ids
}

output "cloud_run_uri" {
  description = "Cloud Run URI, if a service was created."
  value       = try(module.cloud_run[0].uri, null)
}

output "cloud_run_name" {
  description = "Cloud Run service name, if a service was created."
  value       = try(module.cloud_run[0].name, null)
}

output "cloudsql_name" {
  description = "Cloud SQL instance name, if an instance was created."
  value       = try(module.cloudsql[0].name, null)
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name, if an instance was created."
  value       = try(module.cloudsql[0].connection_name, null)
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address, if an instance was created."
  value       = try(module.cloudsql[0].private_ip_address, null)
}
