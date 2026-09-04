# GCP Terraform for agents and microservices

Reusable **modules** for Cloud Storage, IAM, Secret Manager, and Cloud Run. Each **agent / microservice** has its own folder (starting with `via-supervisor`). Environment values live under that folder in `environments/`. Each agent has a **dedicated Terraform state bucket**.

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

## Naming convention

```text
<product_name>-<environment>-<resource>
```

For `via-supervisor` + `prod`:

| You pass | Created name |
| --- | --- |
| `buckets = { bucket = {} }` | `via-supervisor-prod-bucket` |
| `runtime_sa_resource = "sa"` | `via-supervisor-prod-sa` |
| `secret_keys = ["app-config"]` | `via-supervisor-prod-app-config` |
| `cloud_run.resource = "run"` | `via-supervisor-prod-run` |
| Remote backend | `via-supervisor-tfstate` (prefix `prod`) |

## Security defaults

- Buckets: uniform IAM, public access prevention, versioning, no `allUsers`
- IAM: no service account keys; owner/editor/viewer rejected
- Secrets: Terraform creates the secret resource only — no payloads in tfvars
- Cloud Run: dedicated SA, CPU/memory limits, no unauthenticated invokers, no `:latest` image
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
terraform apply

# 2. Agent stack
cd ..
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl

terraform plan \
  -var="environment=dev" \
  -var-file=environments/dev.tfvars.example

terraform apply \
  -var="environment=dev" \
  -var-file=environments/dev.tfvars.example
```

`product_name` defaults to `via-supervisor`.

## Azure DevOps

1. Create a pipeline from `azure-pipelines.yml`.
2. Add secret `GCP_SERVICE_ACCOUNT_JSON`.
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
2. Set `product_name` default in `<new-agent>/variables.tf` and `<new-agent>/remote-backend/variables.tf`.
3. Edit `<new-agent>/environments/` and `<new-agent>/backend.hcl.example` (`bucket = "<new-agent>-tfstate"`).
4. Apply `<new-agent>/remote-backend` once to create `gs://<new-agent>-tfstate`.
5. Run the pipeline with `productName=<new-agent>`.

Leave `modules/` unchanged.
