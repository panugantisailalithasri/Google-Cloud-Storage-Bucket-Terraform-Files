# via-superagent stack for DevSecOps and Production.
# Calls reusable templates in ../modules. Env values: environments/<env>.tfvars
# GCP names are composed in naming.tf as productname-ENVname-Resourcename.
# Cloud Run runtime identity = var.runtime_service_account_email (existing SA, no SA created here).

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  location = var.location

  labels = merge(
    {
      product     = var.product_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels
  )

  vpc_network_uri = startswith(var.vpc_network, "projects/") ? var.vpc_network : "projects/${var.project_id}/global/networks/${var.vpc_network}"
  vpc_subnet_uri  = startswith(var.vpc_subnet, "projects/") ? var.vpc_subnet : "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.vpc_subnet}"

  required_apis = toset(concat(
    [
      "iam.googleapis.com",
      "iamcredentials.googleapis.com",
      "compute.googleapis.com",
      "servicenetworking.googleapis.com",
    ],
    length(var.buckets) > 0 ? ["storage.googleapis.com"] : [],
    length(var.secrets) > 0 ? ["secretmanager.googleapis.com"] : [],
    length(var.sql_instances) > 0 ? ["sqladmin.googleapis.com"] : [],
    length(var.cloud_run_services) > 0 ? [
      "run.googleapis.com",
      "artifactregistry.googleapis.com",
      "aiplatform.googleapis.com",
      "cloudtrace.googleapis.com",
      "telemetry.googleapis.com",
    ] : [],
  ))

  # Prefer the conventional "sql" handle; otherwise the first instance.
  primary_sql = length(var.sql_instances) == 0 ? null : try(module.sql["sql"], values(module.sql)[0])

  cloud_run_urls = {
    for key, svc in var.cloud_run_services :
    key => "https://${local.cloud_run_names[key]}-${data.google_project.this.number}.${var.region}.run.app"
  }

  generated_config_objects = {
    for key, obj in var.gcs_config_objects : key => jsonencode({
      product_name            = var.product_name
      environment             = var.environment
      project_id              = var.project_id
      region                  = var.region
      config_backend          = "gcp"
      config_reload_id        = var.image_tag
      agent_url               = try(local.cloud_run_urls[key], null)
      gcs_config_bucket       = local.bucket_names[obj.bucket_key]
      gcs_config_object       = obj.object_name
      runtime_service_account = var.runtime_service_account_email
      secrets                 = local.secret_names
      gemini_enterprise       = var.gemini_enterprise
      observability           = var.observability
      pac_external            = var.pac_external
      sql = {
        for sql_key, inst in module.sql : sql_key => {
          name            = inst.name
          connection_name = inst.connection_name
          private_ip      = inst.private_ip_address
          unix_socket     = "/cloudsql/${inst.connection_name}"
          databases       = inst.database_names
        }
      }
    })
  }

  config_object_contents = {
    for key, obj in var.gcs_config_objects : key => (
      contains(nonsensitive(keys(var.config_object_payloads)), key) && var.config_object_payloads[key] != ""
      ? var.config_object_payloads[key]
      : local.generated_config_objects[key]
    )
  }
}

resource "google_project_service" "required" {
  for_each = var.enable_apis ? local.required_apis : toset([])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "secrets" {
  source = "../modules/secret-manager"

  project_id = var.project_id
  labels     = local.labels
  secrets = {
    for key in keys(var.secrets) : local.secret_names[key] => {
      accessors = [local.runtime_sa_member]
    }
  }
  secret_payloads = merge(
    {
      for key, payload in var.secret_payloads : local.secret_names[key] => payload
      if payload != null && payload != ""
    },
    {
      for key, inst in var.sql_instances : local.secret_names[inst.connection_secret_key] => module.sql[key].connection_json
      if inst.connection_secret_key != null && inst.app_user != null && inst.app_user != ""
    },
  )

  depends_on = [google_project_service.required, module.sql]
}

module "buckets" {
  source   = "../modules/gcs-bucket"
  for_each = var.buckets

  project_id         = var.project_id
  name               = local.bucket_names[each.key]
  location           = local.location
  storage_class      = each.value.storage_class
  force_destroy      = each.value.force_destroy
  versioning_enabled = each.value.versioning_enabled
  lifecycle_age_days = each.value.lifecycle_age_days
  kms_key_name       = each.value.kms_key_name
  labels             = local.labels

  iam_members = concat(
    [
      {
        role   = each.value.runtime_role
        member = local.runtime_sa_member
      }
    ],
    each.value.extra_iam_members
  )

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_object" "config" {
  for_each = var.gcs_config_objects

  bucket       = module.buckets[each.value.bucket_key].name
  name         = each.value.object_name
  content      = local.config_object_contents[each.key]
  content_type = "application/json"
}

module "sql" {
  source   = "../modules/cloud-sql"
  for_each = var.sql_instances

  project_id          = var.project_id
  name                = local.sql_names[each.key]
  region              = var.region
  edition             = each.value.edition
  database_version    = each.value.database_version
  tier                = each.value.tier
  disk_size_gb        = each.value.disk_size_gb
  private_network     = local.vpc_network_uri
  ssl_mode            = each.value.ssl_mode
  databases           = each.value.databases
  iam_authentication  = each.value.iam_authentication
  pitr_enabled        = each.value.pitr_enabled
  query_insights      = each.value.query_insights
  deletion_protection = each.value.deletion_protection
  kms_key_name        = each.value.kms_key_name
  labels              = local.labels
  app_user            = coalesce(each.value.app_user, "")

  depends_on = [google_project_service.required]
}

module "cloud_run" {
  source   = "../modules/cloud-run"
  for_each = var.cloud_run_services

  project_id            = var.project_id
  name                  = local.cloud_run_names[each.key]
  location              = var.region
  image                 = "${each.value.image_repository}:${var.image_tag}"
  service_account_email = var.runtime_service_account_email
  port                  = each.value.port
  cpu                   = each.value.cpu
  memory                = each.value.memory
  min_instances         = each.value.min_instances
  max_instances         = each.value.max_instances
  concurrency           = each.value.concurrency
  timeout_seconds       = each.value.timeout_seconds
  vpc_network           = var.cloud_run_direct_vpc ? local.vpc_network_uri : ""
  vpc_subnet            = var.cloud_run_direct_vpc ? local.vpc_subnet_uri : ""
  vpc_egress            = var.vpc_egress
  command               = each.value.command
  args                  = each.value.args
  cloud_sql_instances   = [for inst in module.sql : inst.connection_name]
  # Match live via-superagent-dso: only these env vars. Everything else is in GCS JSON.
  env_vars = merge(
    {
      PAC_CONFIG_BACKEND    = "gcp"
      GOOGLE_CLOUD_PROJECT  = var.project_id
      GOOGLE_CLOUD_LOCATION = var.region
      CONFIG_RELOAD_ID      = var.image_tag
    },
    each.value.env_vars,
  )
  secret_env_vars = merge(
    { for env_name, secret_key in each.value.secret_env_keys : env_name => local.secret_names[secret_key] },
    each.value.extra_secret_env_vars,
  )
  ingress               = each.value.ingress
  allow_unauthenticated = each.value.allow_unauthenticated
  invoker_members       = each.value.extra_invoker_members
  deletion_protection   = each.value.deletion_protection
  labels                = local.labels

  depends_on = [
    google_project_service.required,
    module.secrets,
    module.buckets,
    module.sql,
    google_storage_bucket_object.config,
  ]
}
