output "product_name" {
  description = "Product name used for this stack."
  value       = var.product_name
}

output "environment" {
  description = "Environment used for this stack."
  value       = var.environment
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
