resource "google_cloud_run_v2_service" "this" {
  name                 = var.name
  project              = var.project_id
  location             = var.location
  ingress              = var.ingress
  deletion_protection  = var.deletion_protection
  labels               = var.labels
  invoker_iam_disabled = false

  template {
    service_account                  = var.service_account_email
    timeout                          = "${var.timeout_seconds}s"
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = var.concurrency

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    dynamic "vpc_access" {
      for_each = var.vpc_network != "" && var.vpc_subnet != "" ? [1] : []

      content {
        egress = var.vpc_egress

        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnet
        }
      }
    }

    dynamic "volumes" {
      for_each = length(var.cloud_sql_instances) > 0 ? [1] : []

      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = var.cloud_sql_instances
        }
      }
    }

    containers {
      image = var.image
      # Only override image ENTRYPOINT/CMD when tfvars set a non-empty list.
      # Passing command = [] / null has cleared the image command on Cloud Run
      # and the process exits before it can listen on PORT.
      command = length(coalesce(var.command, [])) > 0 ? var.command : null
      args    = length(coalesce(var.args, [])) > 0 ? var.args : null

      ports {
        container_port = var.port
      }

      resources {
        cpu_idle          = var.min_instances > 0 ? false : true
        startup_cpu_boost = true
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Cloud Run fails the revision if nothing listens on PORT. Give the
      # Python/ADK import path time to bind (image ENV PORT/HOST is 8000/0.0.0.0).
      startup_probe {
        failure_threshold     = 36
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 5

        tcp_socket {
          port = var.port
        }
      }

      dynamic "volume_mounts" {
        for_each = length(var.cloud_sql_instances) > 0 ? [1] : []

        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      dynamic "env" {
        for_each = var.env_vars

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars

        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    # Never delete the live service. A tainted instance still plans replace;
    # prevent_destroy stops apply from removing Cloud Run. Image, env, and
    # service_account updates still apply in place as new revisions.
    # Do not ignore template.service_account — DSO was created with
    # ado-deployer-v3 and must move to via-*-dso-sa.
    prevent_destroy = true
    ignore_changes = [
      client,
      client_version,
      traffic,
      invoker_iam_disabled,
      launch_stage,
      annotations,
      template[0].volumes,
      template[0].containers[0].volume_mounts,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}

# Cognito OAuth is enforced inside VIA; public invoke is required for the browser login redirect.
#checkov:skip=CKV_GCP_114:Application authenticates with Cognito OAuth
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
