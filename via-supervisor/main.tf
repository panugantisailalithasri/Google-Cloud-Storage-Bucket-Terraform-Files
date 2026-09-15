# via-supervisor DSO stack.
# Calls reusable templates in ../modules. Env values: environments/<env>.tfvars

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

module "service_accounts" {
  source   = "../modules/iam"
  for_each = var.service_accounts

  project_id    = var.project_id
  account_id    = each.value.account_id
  display_name  = each.value.display_name
  description   = each.value.description
  project_roles = each.value.project_roles

  depends_on = [google_project_service.required]
}

module "secrets" {
  source = "../modules/secret-manager"

  project_id = var.project_id
  labels     = local.labels
  secrets = {
    for key, secret in var.secrets : secret.secret_id => {
      accessors = [
        for sa_key in secret.accessor_sa_keys : module.service_accounts[sa_key].member
      ]
    }
  }

  depends_on = [google_project_service.required]
}

module "buckets" {
  source   = "../modules/gcs-bucket"
  for_each = var.buckets

  project_id         = var.project_id
  name               = each.value.name
  location           = local.location
  storage_class      = each.value.storage_class
  force_destroy      = each.value.force_destroy
  versioning_enabled = each.value.versioning_enabled
  lifecycle_age_days = each.value.lifecycle_age_days
  kms_key_name       = each.value.kms_key_name
  labels             = local.labels

  iam_members = concat(
    [
      for sa_key in each.value.accessor_sa_keys : {
        role   = each.value.runtime_role
        member = module.service_accounts[sa_key].member
      }
    ],
    each.value.extra_iam_members
  )

  depends_on = [google_project_service.required]
}

module "sql" {
  source   = "../modules/cloud-sql"
  for_each = var.sql_instances

  project_id          = var.project_id
  name                = each.value.name
  region              = var.region
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
  name                  = each.value.name
  location              = var.region
  image                 = each.value.image
  service_account_email = module.service_accounts[each.value.sa_key].email
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
  env_vars = merge(each.value.env_vars, {
    PRODUCT_NAME                = var.product_name
    ENVIRONMENT                 = var.environment
    GEMINI_ENTERPRISE_APP_ID    = var.gemini_enterprise.application_id
    VIA_AGENT_ID                = var.gemini_enterprise.via_agent_id
    VIA_AGENT_DISPLAY_NAME      = var.gemini_enterprise.agent_display_name
    VIA_TRACING_ENABLED         = tostring(var.observability.via_tracing_enabled)
    PAC_TRACING_ENABLED         = tostring(var.observability.pac_tracing_enabled)
    OTEL_EXPORTER_OTLP_ENDPOINT = var.observability.traces_endpoint
    REGULATORY_MCP_URL          = var.pac_external.regulatory_mcp
    CONCEPT_GRAPH_URL           = var.pac_external.concept_graph
  })
  secret_env_vars = {
    for env_name, secret_key in each.value.secret_env_keys :
    env_name => var.secrets[secret_key].secret_id
  }
  ingress               = each.value.ingress
  allow_unauthenticated = each.value.allow_unauthenticated
  invoker_members = concat(
    [for sa_key in each.value.invoker_sa_keys : module.service_accounts[sa_key].member],
    each.value.extra_invoker_members
  )
  deletion_protection = each.value.deletion_protection
  labels              = local.labels

  depends_on = [
    google_project_service.required,
    module.secrets,
    module.sql,
  ]
}
