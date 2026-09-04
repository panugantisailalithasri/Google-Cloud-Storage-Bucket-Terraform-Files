# GCP Terraform for agents and microservices

Reusable **modules** for Cloud Storage, IAM, Secret Manager, and Cloud Run. Each **agent / microservice** has its own folder (starting with `via-supervisor`). Environment values live under that folder in `environments/`.

Azure DevOps runs Checkov, then `terraform plan` / `apply`. State is `gs://terraform-dev-agent/<agent>/<env>`.

## Layout

```
modules/                      Reusable GCP templates (do not run Terraform here)
  gcs-bucket/
  iam/
  secret-manager/
  cloud-run/

via-supervisor/               This agent's stack (run Terraform here)
  main.tf                     Calls the modules
  environments/
    dev.tfvars.example
    prod.tfvars.example

azure-pipelines.yml
scripts/scan.sh
```

A new agent is a copy of `via-supervisor/` renamed to the product name, plus its own `environments/` files.

## Naming convention

```text
<product_name>-<environment>-<resource>
```

`product_name` comes from the agent folder (default `via-supervisor`). `environment` comes from `environments/<env>.tfvars`. `<resource>` is the suffix you pass (`bucket`, `sa`, `run`, …).

For `via-supervisor` + `prod`:

| You pass | Created name |
| --- | --- |
| `buckets = { bucket = {} }` | `via-supervisor-prod-bucket` |
| `runtime_sa_resource = "sa"` | `via-supervisor-prod-sa` |
| `secret_keys = ["app-config"]` | `via-supervisor-prod-app-config` |
| `cloud_run.resource = "run"` | `via-supervisor-prod-run` |
| State prefix | `via-supervisor/prod` |

Pass only the suffix. Do not put product or env in the key.

```hcl
buckets = {
  bucket = {}
  logs   = {}
}
```

Creates `via-supervisor-prod-bucket` and `via-supervisor-prod-logs`.

## Security defaults

- Buckets: uniform IAM, public access prevention, versioning, no `allUsers`
- IAM: no service account keys; owner/editor/viewer rejected
- Secrets: Terraform creates the secret resource only — no payloads in tfvars
- Cloud Run: dedicated SA, CPU/memory limits, no unauthenticated invokers, no `:latest` image

## Prerequisites

- Terraform >= 1.5
- GCP project `freyr-ai`
- Access to state bucket `terraform-dev-agent`

```bash
gcloud auth application-default login
gcloud config set project freyr-ai
```

## Local usage

```bash
cd via-supervisor
cp backend.hcl.example backend.hcl   # set prefix to via-supervisor/dev or via-supervisor/prod
terraform init -backend-config=backend.hcl

terraform plan \
  -var="environment=dev" \
  -var-file=environments/dev.tfvars.example

terraform apply \
  -var="environment=dev" \
  -var-file=environments/dev.tfvars.example
```

`product_name` defaults to `via-supervisor`. Override with `-var="product_name=..."` only if needed.

To enable Cloud Run, set `cloud_run` in the env tfvars with a pinned image (not `:latest`).

## Azure DevOps

1. Create a pipeline from `azure-pipelines.yml`.
2. Add secret `GCP_SERVICE_ACCOUNT_JSON`.
3. Create ADO environments `gcp-dev` and `gcp-prod` (approval on prod).
4. Run with:
   - `productName`: agent folder (`via-supervisor`)
   - `environment`: `dev` or `prod`
   - `action`: `plan` or `apply`

The pipeline uses `<productName>/` as the Terraform working directory and `<productName>/environments/<env>.tfvars`.

## Checkov

```bash
./scripts/scan.sh
```

The ADO Validate stage fails on policy violations.

## Adding another agent

1. Copy `via-supervisor/` to `<new-agent>/`.
2. Set `product_name` default in that folder’s `variables.tf` to `<new-agent>`.
3. Edit `<new-agent>/environments/dev.tfvars.example` and `prod.tfvars.example`.
4. Run the pipeline with `productName=<new-agent>`.

Leave `modules/` unchanged.
