locals {
  stack_labels = merge(
    {
      environment = var.environment
      application = "via-supervisor"
      managed_by  = "terraform"
    },
    var.common_labels,
  )
}

module "gcs_bucket" {
  count  = var.gcs_bucket.enabled ? 1 : 0
  source = "../../../modules/gcs_bucket"

  project_id                  = var.project_id
  name                        = var.gcs_bucket.name
  location                    = var.gcs_bucket.location
  storage_class               = var.gcs_bucket.storage_class
  requester_pays              = var.gcs_bucket.requester_pays
  uniform_bucket_level_access = var.gcs_bucket.uniform_bucket_level_access
  public_access_prevention    = var.gcs_bucket.public_access_prevention
  versioning_enabled          = var.gcs_bucket.versioning_enabled
  soft_delete_retention_days  = var.gcs_bucket.soft_delete_retention_days
  force_destroy               = var.gcs_bucket.force_destroy
  labels                      = merge(local.stack_labels, var.gcs_bucket.labels)
  additional_iam_members      = var.gcs_bucket.additional_iam_members
}

module "cloudsql" {
  count  = var.cloudsql.enabled ? 1 : 0
  source = "../../../modules/cloudsql_postgres"

  project_id                                    = var.project_id
  name                                          = var.cloudsql.name
  region                                        = var.cloudsql.region
  database_version                              = var.cloudsql.database_version
  edition                                       = var.cloudsql.edition
  tier                                          = var.cloudsql.tier
  availability_type                             = var.cloudsql.availability_type
  disk_type                                     = var.cloudsql.disk_type
  disk_size                                     = var.cloudsql.disk_size
  disk_autoresize                               = var.cloudsql.disk_autoresize
  private_network_name                          = var.vpc_name
  network_project_id                            = var.network_project_id
  ipv4_enabled                                  = var.cloudsql.ipv4_enabled
  ssl_mode                                      = var.cloudsql.ssl_mode
  enable_private_path_for_google_cloud_services = var.cloudsql.enable_private_path_for_google_cloud_services
  authorized_networks                           = var.cloudsql.authorized_networks
  database_flags                                = var.cloudsql.database_flags
  labels                                        = merge(local.stack_labels, var.cloudsql.labels)
  deletion_protection                           = var.cloudsql.deletion_protection
  deletion_protection_enabled                   = var.cloudsql.deletion_protection_enabled
}
