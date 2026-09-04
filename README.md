# GCP Terraform for agents and microservices

Reusable **modules** for Cloud Storage, IAM, Secret Manager, and Cloud Run. Each **agent / microservice** has its own folder (starting with `via-supervisor`). Environment values live under that folder in `environments/`. Each agent has a **dedicated Terraform state bucket**.

**via-supervisor** deploys Cloud Storage and Secret Manager only (no Cloud Run). Bucket count is data: this agent defines **one** bucket; another agent uses the **same** `modules/gcs-bucket` template with **two** keys.

## Layout

```
modules/                         Reusable GCP templates (do not run Terraform here)
  gcs-bucket/
  iam/
  secret-manager/
  cloud-run/

via-supervisor/                  This agent's stack
  remote-backend/                Creates gs://via-supervisor-tfstate (run once)
  environments/
    dev.tfvars.example           Dev values
    prod.tfvars.example          Prod values
  main.tf                        Calls the modules
```

A new agent is a copy of `via-supervisor/` renamed to the product name. That copy gets its own state bucket (`<product_name>-tfstate`).

## Remote backend (one bucket per agent)

| Agent folder | State bucket | Env prefix |
| --- | --- | --- |
| `via-supervisor` | `gs://via-supervisor-tfstate` | `dev` or `prod` |
| `agent-b` (later) | `gs://agent-b-tfstate` | `dev` or `prod` |

The bucket must exist before `terraform init` of the agent stack. Create it once:

```bash
cd via-supervisor/remote-backend
terraform init
terraform apply
```

That uses the `gcs-bucket` module (private, versioned, no public access). Then init the agent stack against that bucket:

```bash
cd via-supervisor
cp backend.hcl.example backend.hcl   # bucket = via-supervisor-tfstate, prefix = dev or prod
terraform init -backend-config=backend.hcl
```

ADO sets `bucket=$(productName)-tfstate` and `prefix=$(environment)` automatically.

## One bucket vs two buckets (same module)

`modules/gcs-bucket` is the template. The agent env file decides how many times it is instantiated (`for_each = var.buckets`).

**via-supervisor (agent A) — 1 bucket + secrets**

```hcl
buckets = {
  bucket = {}
}
secret_keys = ["app-config"]
```

Creates `via-supervisor-dev-bucket` and three secrets: `via-supervisor-dev-via-supervisor`, `via-supervisor-dev-via-superagent`, and `via-supervisor-dev-cognito`. Cloud Run is not created.

**Another agent (agent B) — 2 buckets, same module**

Copy `via-supervisor/` to `agent-b/`, then in `agent-b/environments/dev.tfvars`:

```hcl
buckets = {
  bucket = {}
  data   = {}
}
```

Creates `agent-b-dev-bucket` and `agent-b-dev-data`. Still `source = "../modules/gcs-bucket"`. That agent gets its own state bucket `gs://agent-b-tfstate` from `agent-b/remote-backend/`.

## Naming convention

```text
<product_name>-<environment>-<resource>
```

For `via-supervisor` + `prod`:

| You pass | Created name |
| --- | --- |
| `buckets = { bucket = {} }` | `via-supervisor-prod-bucket` |
| `runtime_sa_resource = "sa"` | `via-supervisor-prod-sa` |
| `secret_keys` for via-supervisor, via-superagent, cognito | `via-supervisor-prod-via-supervisor`, `via-supervisor-prod-via-superagent`, `via-supervisor-prod-cognito` |
| Remote backend | `via-supervisor-tfstate` (prefix `prod`) |

## Security defaults

- Buckets: uniform IAM, public access prevention, versioning, no `allUsers`
- IAM: no service account keys; owner/editor/viewer rejected
- Secrets: Terraform creates the secret resource only — no payloads in tfvars
- via-supervisor uses Cloud Storage and Secret Manager only. Cloud Run stays in the stack as an optional module (`count = 0` unless `cloud_run` is set) so other agents can enable it without changing `modules/`.
- State buckets: same private bucket module; `force_destroy` is false

## Prerequisites

- Terraform >= 1.5
- GCP project `freyr-ai`

```bash
gcloud auth application-default login
gcloud config set project freyr-ai
```

## Local usage

```bash
# 1. Once per agent: create the dedicated state bucket
cd via-supervisor/remote-backend
terraform init
terraform apply -var-file=terraform.tfvars.example

# 2. Agent stack
cd ..
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl

terraform plan -var-file=environments/dev.tfvars.example

terraform apply -var-file=environments/dev.tfvars.example
```

All stack inputs come from `environments/<env>.tfvars` (see `variables.tf`). Do not rely on defaults in `variables.tf`.

## Azure DevOps

The pipeline uses the ARM service connection `GCP_freyrai_service_role` to mint an OIDC token, then exchanges it for GCP credentials via Workload Identity Federation (`ado-deployer-v3@freyr-ai.iam.gserviceaccount.com`). No GCP JSON key is stored in the pipeline.

1. Create a pipeline from `azure-pipelines.yml`.
2. Ensure the ARM service connection `GCP_freyrai_service_role` exists and this pipeline is allowed to use it.
3. Create ADO environments `gcp-dev` and `gcp-prod` (approval on prod).
4. Create the agent state bucket (`<productName>-tfstate`) once via `remote-backend/` before the first plan.
5. Run with:
   - `productName`: agent folder (`via-supervisor`) → bucket `via-supervisor-tfstate`
   - `environment`: `dev` or `prod` → state prefix
   - `action`: `plan` or `apply`

## Checkov

```bash
./scripts/scan.sh
```

## Adding another agent

1. Copy `via-supervisor/` to `<new-agent>/`.
2. Edit `<new-agent>/environments/*.tfvars.example` (including `product_name`) and `<new-agent>/remote-backend/terraform.tfvars.example`.
3. Edit `<new-agent>/backend.hcl.example` (`bucket = "<new-agent>-tfstate"`).
4. Apply `<new-agent>/remote-backend` once to create `gs://<new-agent>-tfstate`.
5. Run the pipeline with `productName=<new-agent>`.

Leave `modules/` unchanged.
