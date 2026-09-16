# Resource names are composed here, not stored as full strings in tfvars.
# Format: productname-ENVname-Resourcename  (lowercased for GCP)
#
#   product  = each resource's product_name override, or var.product_name
#   env      = var.environment from environments/<env>.tfvars (devsecops / prod)
#   resource = each resource's resource_name, or the map key with underscores → hyphens
#
# sql_instances supports name_override for pre-existing GCP instances whose name
# cannot be changed (Cloud SQL instances cannot be renamed). Always prefer the
# standard composition; name_override must be documented in tfvars when used.

locals {
  environment_name = lower(var.environment)

  bucket_names = {
    for key, bucket in var.buckets :
    key => lower(format("%s-%s-%s",
      coalesce(bucket.product_name, var.product_name),
      local.environment_name,
      coalesce(bucket.resource_name, replace(key, "_", "-")),
    ))
  }

  secret_names = {
    for key, secret in var.secrets :
    key => lower(format("%s-%s-%s",
      coalesce(secret.product_name, var.product_name),
      local.environment_name,
      coalesce(secret.resource_name, replace(key, "_", "-")),
    ))
  }

  sql_names = {
    for key, inst in var.sql_instances :
    key => inst.name_override != null ? lower(inst.name_override) : lower(format("%s-%s-%s",
      coalesce(inst.product_name, var.product_name),
      local.environment_name,
      coalesce(inst.resource_name, replace(key, "_", "-")),
    ))
  }

  cloud_run_names = {
    for key, svc in var.cloud_run_services :
    key => lower(format("%s-%s-%s",
      coalesce(svc.product_name, var.product_name),
      local.environment_name,
      coalesce(svc.resource_name, replace(key, "_", "-")),
    ))
  }

  runtime_sa_member = "serviceAccount:${var.runtime_service_account_email}"
}
