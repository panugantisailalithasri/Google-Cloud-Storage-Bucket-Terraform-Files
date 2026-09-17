# via-supervisor stack for DevSecOps and Production.
# Calls reusable templates in ../modules. Env values: environments/<env>.tfvars
# GCP names are composed in naming.tf as productname-ENVname-Resourcename.
# Cloud Run runtime identity = var.runtime_service_account_email (existing SA, no SA created here).

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

  depends_on = [google_project_service.required]
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

# Import the pre-existing Cloud SQL instance so Terraform manages it without
# trying to create it again. Once the instance is in state this block is a no-op.
import {
  for_each = var.sql_instances
  to       = module.sql[each.key].google_sql_database_instance.this
  id       = "projects/${var.project_id}/instances/${local.sql_names[each.key]}"
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
  vpc_network           = local.vpc_network_uri
  vpc_subnet            = local.vpc_subnet_uri
  vpc_egress            = var.vpc_egress
  env_vars = merge(
    each.value.env_vars,
    {
      PRODUCT_NAME                = coalesce(each.value.product_name, var.product_name)
      ENVIRONMENT                 = var.environment
      RESOURCE_NAME               = local.cloud_run_names[each.key]
      GEMINI_ENTERPRISE_APP_ID    = var.gemini_enterprise.application_id
      VIA_AGENT_ID                = var.gemini_enterprise.via_agent_id
      VIA_AGENT_DISPLAY_NAME      = var.gemini_enterprise.agent_display_name
      VIA_TRACING_ENABLED         = tostring(var.observability.via_tracing_enabled)
      PAC_TRACING_ENABLED         = tostring(var.observability.pac_tracing_enabled)
      OTEL_EXPORTER_OTLP_ENDPOINT = var.observability.traces_endpoint
      REGULATORY_MCP_URL          = var.pac_external.regulatory_mcp
      CONCEPT_GRAPH_URL           = var.pac_external.concept_graph
    },
    each.value.config_bucket_key == null ? {} : {
      GCS_CONFIG_BUCKET = local.bucket_names[each.value.config_bucket_key]
    },
    each.value.session_secret_key == null ? {} : {
      SESSION_SERVICE_SECRET_NAME = local.secret_names[each.value.session_secret_key]
    },
    each.value.memory_secret_key == null ? {} : {
      MEMORY_SERVICE_SECRET_NAME = local.secret_names[each.value.memory_secret_key]
    },
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
    module.sql,
  ]
}
