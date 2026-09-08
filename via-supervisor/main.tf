# via-supervisor agent stack.
# Calls reusable templates in ../modules. Env values: environments/<env>.tfvars

locals {
  # Naming convention: <product_name>-<environment>-<resource>
  location = coalesce(var.location, var.region)

  labels = merge(
    {
      product     = var.product_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.labels
  )

  sa_name = "${var.product_name}-${var.environment}-${var.runtime_sa_resource}"

  secret_ids = {
    for key in var.secret_keys : key => "${var.product_name}-${var.environment}-${key}"
  }

  # Enable only the APIs this agent actually uses.
  required_apis = toset(concat(
    ["iam.googleapis.com", "iamcredentials.googleapis.com"],
    length(var.buckets) > 0 ? ["storage.googleapis.com"] : [],
    length(var.secret_keys) > 0 ? ["secretmanager.googleapis.com"] : [],
    var.cloud_run != null ? ["run.googleapis.com", "artifactregistry.googleapis.com"] : [],
    var.cloudsql != null ? ["sqladmin.googleapis.com", "servicenetworking.googleapis.com"] : [],
  ))

  # Module arguments are evaluated even when count = 0.
  cloud_run = coalesce(var.cloud_run, {
    image               = "unused.local/app:disabled"
    resource            = "run"
    port                = 8080
    cpu                 = "1"
    memory              = "512Mi"
    min_instances       = 0
    max_instances       = 3
    timeout_seconds     = 60
    env_vars            = {}
    secret_env_vars     = {}
    ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    invoker_members     = []
    deletion_protection = true
  })

  cloud_run_name = "${var.product_name}-${var.environment}-${local.cloud_run.resource}"

  cloudsql = coalesce(var.cloudsql, {
    name                                          = "unused-cloudsql-instance"
    region                                        = var.region
    database_version                              = "POSTGRES_18"
    edition                                       = "ENTERPRISE"
    tier                                          = "db-custom-1-3840"
    availability_type                             = "ZONAL"
    disk_type                                     = "PD_SSD"
    disk_size                                     = 10
    disk_autoresize                               = true
    ipv4_enabled                                  = false
    ssl_mode                                      = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    enable_private_path_for_google_cloud_services = false
    authorized_networks                           = []
    database_flags                                = []
    deletion_protection                           = false
    deletion_protection_enabled                   = false
  })
}

resource "google_project_service" "required" {
  for_each = var.enable_apis ? local.required_apis : toset([])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "runtime_sa" {
  source = "../modules/iam"

  project_id    = var.project_id
  account_id    = trimsuffix(substr(local.sa_name, 0, 30), "-")
  display_name  = "${var.product_name} ${var.environment} runtime"
  description   = "Runtime identity for ${local.sa_name}"
  project_roles = var.runtime_sa_roles

  depends_on = [google_project_service.required]
}

module "secrets" {
  source = "../modules/secret-manager"

  project_id = var.project_id
  labels     = local.labels
  secrets = {
    for key, secret_id in local.secret_ids : secret_id => {
      accessors = [module.runtime_sa.member]
    }
  }

  depends_on = [google_project_service.required]
}

# Same gcs-bucket module for every agent. How many buckets is var.buckets:
#   1 key  → agent A (via-supervisor-dev-bucket)
#   2 keys → agent B (via-supervisor-dev-bucket + via-supervisor-dev-data)
module "buckets" {
  source   = "../modules/gcs-bucket"
  for_each = var.buckets

  project_id         = var.project_id
  name               = "${var.product_name}-${var.environment}-${each.key}"
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
        member = module.runtime_sa.member
      }
    ],
    each.value.extra_iam_members
  )

  depends_on = [google_project_service.required]
}

module "cloud_run" {
  source = "../modules/cloud-run"
  count  = var.cloud_run == null ? 0 : 1

  project_id            = var.project_id
  name                  = local.cloud_run_name
  location              = var.region
  image                 = local.cloud_run.image
  service_account_email = module.runtime_sa.email
  port                  = local.cloud_run.port
  cpu                   = local.cloud_run.cpu
  memory                = local.cloud_run.memory
  min_instances         = local.cloud_run.min_instances
  max_instances         = local.cloud_run.max_instances
  timeout_seconds       = local.cloud_run.timeout_seconds
  env_vars = merge(local.cloud_run.env_vars, {
    PRODUCT_NAME = var.product_name
    ENVIRONMENT  = var.environment
  })
  secret_env_vars = {
    for env_name, secret_key in local.cloud_run.secret_env_vars :
    env_name => local.secret_ids[secret_key]
  }
  ingress             = local.cloud_run.ingress
  invoker_members     = local.cloud_run.invoker_members
  deletion_protection = local.cloud_run.deletion_protection
  labels              = local.labels

  depends_on = [
    google_project_service.required,
    module.secrets,
  ]
}

module "cloudsql" {
  source = "../modules/cloudsql-postgres"
  count  = var.cloudsql == null ? 0 : 1

  project_id                                    = var.project_id
  name                                          = local.cloudsql.name
  region                                        = local.cloudsql.region
  private_network_name                          = var.vpc_name
  network_project_id                            = var.network_project_id
  database_version                              = local.cloudsql.database_version
  edition                                       = local.cloudsql.edition
  tier                                          = local.cloudsql.tier
  availability_type                             = local.cloudsql.availability_type
  disk_type                                     = local.cloudsql.disk_type
  disk_size                                     = local.cloudsql.disk_size
  disk_autoresize                               = local.cloudsql.disk_autoresize
  ipv4_enabled                                  = local.cloudsql.ipv4_enabled
  ssl_mode                                      = local.cloudsql.ssl_mode
  enable_private_path_for_google_cloud_services = local.cloudsql.enable_private_path_for_google_cloud_services
  authorized_networks                           = local.cloudsql.authorized_networks
  database_flags                                = local.cloudsql.database_flags
  labels                                        = local.labels
  deletion_protection                           = local.cloudsql.deletion_protection
  deletion_protection_enabled                   = local.cloudsql.deletion_protection_enabled

  depends_on = [google_project_service.required]
}
