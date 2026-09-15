output "product_name" {
  description = "Product name used as the first segment of resource names."
  value       = var.product_name
}

output "environment" {
  description = "Environment name used as the second segment of resource names."
  value       = var.environment
}

output "resource_names" {
  description = "Composed GCP names (productname-ENVname-Resourcename) keyed by stack handle."
  value = {
    service_accounts = local.service_account_names
    buckets          = local.bucket_names
    secrets          = local.secret_names
    sql              = local.sql_names
    cloud_run        = local.cloud_run_names
  }
}

output "service_account_emails" {
  description = "Service account emails keyed by handle."
  value       = { for key, sa in module.service_accounts : key => sa.email }
}

output "bucket_names" {
  description = "Created bucket names keyed by handle."
  value       = { for key, bucket in module.buckets : key => bucket.name }
}

output "secret_ids" {
  description = "Secret Manager IDs keyed by handle."
  value       = local.secret_names
}

output "sql_connection_names" {
  description = "Cloud SQL connection names keyed by handle."
  value       = { for key, inst in module.sql : key => inst.connection_name }
}

output "sql_private_ips" {
  description = "Cloud SQL private IPs keyed by handle (assigned at apply)."
  value       = { for key, inst in module.sql : key => inst.private_ip_address }
}

output "cloud_run_uris" {
  description = "Cloud Run URIs keyed by handle."
  value       = { for key, svc in module.cloud_run : key => svc.uri }
}

output "cloud_run_names" {
  description = "Cloud Run service names keyed by handle."
  value       = { for key, svc in module.cloud_run : key => svc.name }
}
