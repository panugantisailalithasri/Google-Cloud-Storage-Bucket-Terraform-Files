# GCP Terraform modules for agents and microservices

Reusable Terraform modules for **Cloud Storage**, **IAM**, **Secret Manager**, and **Cloud Run**. A single composition stack in `infra/` is reused for every product (for example `via-supervisor`) and environment (`dev`, `prod`). Names, labels, and state paths are derived from variables — not hardcoded product or env values.

Azure DevOps runs Checkov, then `terraform plan` / `apply`, with state in `gs://terraform-dev-agent/<product>/<env>`.

## Layout

```
modules/gcs-bucket/       Cloud Storage bucket (private, versioned, UBLA)
modules/iam/              Runtime service account (no keys, no primitive roles)
modules/secret-manager/   Secret containers + accessor IAM (no secret payloads)
modules/cloud-run/        Cloud Run v2 service (authenticated, pinned image)
infra/                    Composition stack used by ADO
envs/                     Environment defaults (dev / prod)
config/<product>/         Optional per-product overlay
azure-pipelines.yml       Checkov + plan/apply
scripts/scan.sh           Local Checkov scan
```

## Naming convention

Every resource is named:

```text
<product_name>-<environment>-<resource>
```

`product_name` and `environment` are passed dynamically (ADO parameters or `-var`). `<resource>` is the suffix you pass per resource (bucket map key, secret key, Cloud Run `resource`, or `runtime_sa_resource`).

For `product_name=via-supervisor` and `environment=prod`:

| You pass | Created name |
| --- | --- |
| `buckets = { bucket = {} }` | `via-supervisor-prod-bucket` |
| `runtime_sa_resource = "sa"` (default) | `via-supervisor-prod-sa` |
| `secret_keys = ["app-config"]` | `via-supervisor-prod-app-config` |
| `cloud_run.resource = "run"` (default) | `via-supervisor-prod-run` |
| Terraform state prefix | `via-supervisor/prod` |

Pass only the suffix (`bucket`, `sa`, `run`). Do not put the product or env into the key, or the name will be doubled.

Need a second bucket? Add another suffix:

```hcl
buckets = {
  bucket = {}
  logs   = {}
}
```

That creates `via-supervisor-prod-bucket` and `via-supervisor-prod-logs`.

The same modules and `infra/` code are used for every other agent. Add `config/<product>/<env>.tfvars` (or a `.example`) and pass `productName` / `environment` in the pipeline.

## Variables that must stay dynamic

Pass these at plan/apply time (ADO parameters or `-var`):

| Variable | Example | Purpose |
| --- | --- | --- |
| `product_name` | `via-supervisor` | First segment of every resource name |
| `environment` | `dev` or `prod` | Second segment of every resource name |
| `buckets` keys / `secret_keys` / `cloud_run.resource` | `bucket`, `app-config`, `run` | Third segment (`<resource>`) |

Do not default `product_name` or `environment` inside modules. Env files may set `environment` as a convenience; ADO still passes both explicitly so the pipeline is the source of truth.

## Security defaults

- Buckets: uniform bucket-level access, `public_access_prevention = enforced`, versioning, no `allUsers`
- IAM: no service account keys; `roles/owner`, `roles/editor`, and `roles/viewer` are rejected
- Secrets: Terraform creates the secret resource only. Put values in Secret Manager or ADO secret variables, never in tfvars
- Cloud Run: dedicated runtime SA, CPU/memory limits, Gen2, no unauthenticated invokers, image tag `:latest` rejected
- Runtime SA gets `logWriter`, `metricWriter`, and `artifactregistry.reader` at project scope; storage and secret access is on the resource, not the project

## Prerequisites

- Terraform >= 1.5
- GCP project `freyr-ai` (override with `project_id`)
- APIs: Storage, Cloud Run, Secret Manager, IAM, Artifact Registry
- Access to state bucket `terraform-dev-agent` (`roles/storage.objectAdmin`)
- For apply: credentials that can create the resources above

```bash
gcloud auth application-default login
gcloud config set project freyr-ai
```

## Local usage

```bash
cd infra
cp backend.hcl.example backend.hcl   # set prefix to PRODUCT/ENV
terraform init -backend-config=backend.hcl

terraform plan \
  -var="product_name=via-supervisor" \
  -var="environment=dev" \
  -var-file=../envs/dev.tfvars.example \
  -var-file=../config/via-supervisor/dev.tfvars.example

terraform apply \
  -var="product_name=via-supervisor" \
  -var="environment=dev" \
  -var-file=../envs/dev.tfvars.example \
  -var-file=../config/via-supervisor/dev.tfvars.example
```

Add a Cloud Run service by setting `cloud_run` in the product tfvars. Pin an image tag or digest (not `:latest`):

```hcl
cloud_run = {
  image               = "us-east1-docker.pkg.dev/freyr-ai/agents/via-supervisor:1.2.3"
  min_instances       = 0
  max_instances       = 2
  deletion_protection = false
  secret_env_vars = {
    APP_CONFIG = "app-config"
  }
}
```

`APP_CONFIG` maps to the secret short name in `secret_keys`. The stack wires the runtime SA as accessor.

## Azure DevOps

1. Create pipeline from `azure-pipelines.yml`.
2. Add secret variable `GCP_SERVICE_ACCOUNT_JSON` (JSON key or WIF-injected credentials) on the pipeline or in a variable group.
3. Create ADO environments `gcp-dev` and `gcp-prod`. Attach an approval check to `gcp-prod`.
4. Run the pipeline with parameters:
   - `productName`: `via-supervisor` (or another agent)
   - `environment`: `dev` or `prod`
   - `action`: `plan` or `apply`

The pipeline always runs Checkov and `terraform validate`. Apply runs only when `action=apply` and the ADO environment succeeds.

State prefix is `$(productName)/$(environment)` in bucket `terraform-dev-agent`.

## Checkov

Scan modules and the composition stack:

```bash
chmod +x scripts/scan.sh
./scripts/scan.sh
```

The scan fails the ADO **Validate** stage on policy violations.

## Adding another product

1. Copy `config/via-supervisor/` to `config/<new-product>/`.
2. Adjust buckets, secret keys, and optional `cloud_run` image.
3. Run the pipeline with `productName=<new-product>`.

No module or `infra/` code changes are required.

## Module inputs (composition)

| Name | Description | Default |
| --- | --- | --- |
| `product_name` | Product / agent id | *(required)* |
| `environment` | `dev` or `prod` | *(required)* |
| `project_id` | GCP project | `freyr-ai` |
| `region` / `location` | Region; bucket location defaults to region | `us-east1` |
| `buckets` | Map of resource suffix → bucket settings (`bucket` → `…-bucket`) | `{}` |
| `secret_keys` | Resource suffixes for Secret Manager | `[]` |
| `cloud_run` | Service settings; `resource` defaults to `run`; `null` skips Cloud Run | `null` |
| `runtime_sa_resource` | SA name suffix | `sa` |
| `runtime_sa_roles` | Extra project roles for the runtime SA | logging / monitoring / Artifact Registry |
| `enable_apis` | Enable required GCP APIs | `true` |
