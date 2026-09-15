# Resource names are composed here, not stored as full strings in tfvars.
# Format: productname-ENVname-Resourcename  (lowercased for GCP)
#
#   product  = each resource's product_name, or var.product_name (pipeline productName)
#   env      = var.environment from environments/<env>.tfvars (devsecops / prod)
#   resource = each resource's resource_name, or the map key with underscores → hyphens

locals {
  environment_name = lower(var.environment)

  service_account_names = {
    for key, sa in var.service_accounts :
    key => lower(format("%s-%s-%s",
      coalesce(sa.product_name, var.product_name),
      local.environment_name,
      coalesce(sa.resource_name, replace(key, "_", "-")),
    ))
  }

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
    key => lower(format("%s-%s-%s",
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
}

check "service_account_id_length" {
  assert {
    condition     = alltrue([for n in values(local.service_account_names) : length(n) >= 6 && length(n) <= 30])
    error_message = "Composed service account IDs must be 6-30 characters (product-env-resource). Got: ${join(", ", values(local.service_account_names))}"
  }
}
