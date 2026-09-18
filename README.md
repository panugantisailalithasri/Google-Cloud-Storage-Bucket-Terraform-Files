# GCP Terraform for agents and microservices

Reusable **modules** for Cloud Storage, IAM, Secret Manager, Cloud Run, and Cloud SQL. Each **agent / microservice** has its own folder (starting with `via-supervisor`). Environment values live under that folder in `environments/`. Each agent has a **dedicated Terraform state bucket**.

**via-supervisor** deploys the same stack to **DevSecOps** and **Production** in `freyr-ai` / `us-east4`. Only `environments/dev.tfvars` vs `environments/prod.tfvars` (and the pipeline `environment` parameter) change. Terraform composes every GCP name from product, env, and resource suffix.

## Layout

```
modules/                         Reusable GCP templates (do not run Terraform here)
  gcs-bucket/
  iam/
  secret-manager/
  cloud-run/
  cloud-sql/

via-supervisor/                  Stack for VIA supervisor + superagent
  naming.tf                      Composes productname-ENVname-Resourcename
  remote-backend/                Creates gs://via-supervisor-tfstate (run once)
  environments/
    dev.tfvars.example           DevSecOps values (environment = devsecops)
    prod.tfvars.example          Production values (environment = prod)
  main.tf                        Calls the modules
```

## Naming convention

Every GCP resource name is built in `via-supervisor/naming.tf`:

```text
productname-ENVname-Resourcename
```

| Segment | Source |
| --- | --- |
| productname | `var.product_name` (tfvars, overridden by pipeline `productName`) or a per-resource `product_name` (used for `via-superagent`) |
| ENVname | `var.environment` from the env tfvars (`devsecops` or `prod`) |
| Resourcename | per-resource `resource_name` (`sa`, `bucket`, `run`, `sql`, `secret`, …) |

Names are lowercased. tfvars hold **suffixes and settings only** — not full strings like `via-supervisor-dev-sa`.

DevSecOps examples (`product_name = via-supervisor`, `environment = devsecops`):

| Handle | Composed name |
| --- | --- |
| Supervisor SA | `via-supervisor-devsecops-sa` |
| Superagent SA | `via-superagent-devsecops-sa` |
| Supervisor bucket | `via-supervisor-devsecops-bucket` |
| Superagent bucket | `via-superagent-devsecops-bucket` |
| Supervisor Cloud Run | `via-supervisor-devsecops-run` |
| Superagent Cloud Run | `via-superagent-devsecops-run` |
| Cloud SQL (existing) | `via-supervisor-devsecops-east4` |

Production uses the same suffixes with `environment = prod` (`via-supervisor-prod-bucket`, `via-supervisor-prod-sql`, …).

The remote-backend bucket stays `<product_name>-tfstate` (not env-scoped). State isolation is the backend prefix (`dev` / `prod`).

## DSO resources (settings from tfvars)

| Kind | What Terraform creates |
| --- | --- |
| Cloud Run | Supervisor (public invoke; Cognito in-app) and superagent (invoker = supervisor SA) |
| GCS | One config bucket per product |
| Secrets | Supervisor/superagent secret, session, memory, cognito |
| Cloud SQL | DevSecOps: existing `via-supervisor-devsecops-east4` only. Production: supervisor, superagent, and memory instances |
| VPC / subnet | `freya-ai-dev-vpc` / `freya-ai-dev-subnet-us-east4` |

GCS JSON config objects are not uploaded by Terraform. `GCS_CONFIG_BUCKET` is set only when `config_bucket_name` is provided. The composed `product-env-bucket` is created empty; pointing Cloud Run at a missing object makes the process exit before it listens on `PORT`.

Terraform does **not** grant project IAM (for example `roles/cloudsql.client`). The ADO identity `ado-deployer-v3@freyr-ai.iam.gserviceaccount.com` cannot call `resourcemanager.projects.setIamPolicy`. A GCP admin must grant Cloud SQL client (and other project roles) on that existing SA outside this stack.

### Cloud Run "failed to listen on PORT"

The image already sets `PORT=8000` and `HOST=0.0.0.0`. Terraform sets `container_port = 8000` (Cloud Run then injects `PORT`; do not also set `PORT` in `env_vars`). If apply still fails with *container failed to start and listen on PORT=8000*, Cloud Run reached the process and the process never bound — usually a crash during import (missing GCS JSON, bad secret payload, Cloud SQL), not a port mismatch.

Check the revision logs first:

```text
https://console.cloud.google.com/run/detail/us-east4/via-supervisor-devsecops-run/logs?project=freyr-ai
```

Confirm the config object exists in the bucket Cloud Run is pointed at:

```bash
gcloud storage ls gs://via-supervisor-devsecops-bucket/ff-freya-supervisor/dev/ff-freya-supervisor-common.json
```

If the JSON lives in another bucket, set `config_bucket_name` (or `env_vars.GCS_CONFIG_BUCKET`) on the Cloud Run service. Upload is outside Terraform:

```bash
gcloud storage cp ff-freya-supervisor-common.json \
  gs://via-supervisor-devsecops-bucket/ff-freya-supervisor/dev/ff-freya-supervisor-common.json
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

ADO sets `bucket=$(productName)-tfstate` and `prefix=$(environment)` automatically, and passes `-var=product_name=$(productName)` so names follow the pipeline product. Pipeline variables also record DSO project `freyr-ai`, region `us-east4`, VPC `freya-ai-dev-vpc`, and subnet `freya-ai-dev-subnet-us-east4`.

## Security defaults

- Buckets: uniform IAM, public access prevention, versioning, no public principals
- IAM: no service account keys; owner/editor/viewer rejected
- Secrets: Terraform creates the secret resource only — no payloads in tfvars
- Superagent Cloud Run is not publicly invokable; only the supervisor SA has `roles/run.invoker`
- Supervisor Cloud Run allows `allUsers` because Cognito OAuth is enforced in the application
- Cloud SQL has no public IP; private VPC only
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

# DevSecOps
terraform plan -var-file=environments/dev.tfvars.example

# Production
terraform plan -var-file=environments/prod.tfvars.example
```

All stack inputs come from `environments/<env>.tfvars` (see `variables.tf`). Do not rely on defaults in `variables.tf`. Resource **names** are derived in `naming.tf`, not copied from tfvars.

## Azure DevOps

The pipeline uses the ARM service connection `GCP_freyrai_service_role` to mint an OIDC token, then exchanges it for GCP credentials via Workload Identity Federation (`ado-deployer-v3@freyr-ai.iam.gserviceaccount.com`). No GCP JSON key is stored in the pipeline.

1. Create a pipeline from `azure-pipelines.yml`.
2. Ensure the ARM service connection `GCP_freyrai_service_role` exists and this pipeline is allowed to use it.
3. Create ADO environments `gcp-dev` and `gcp-prod` (approval on prod).
4. Create the agent state bucket (`<productName>-tfstate`) once via `remote-backend/` before the first plan.
5. Run with:
   - `productName`: agent folder (`via-supervisor`) → state bucket `via-supervisor-tfstate` and first name segment
   - `environment`: `dev` (DevSecOps tfvars) or `prod` (Production tfvars) → state prefix
   - `action`: `plan` or `apply`

## Checkov

```bash
./scripts/scan.sh
```

## Adding another agent

1. Copy `via-supervisor/` to `<new-agent>/`.
2. Edit `<new-agent>/environments/*.tfvars.example` (`product_name` and any peer `product_name` overrides) and `<new-agent>/remote-backend/terraform.tfvars.example`.
3. Edit `<new-agent>/backend.hcl.example` (`bucket = "<new-agent>-tfstate"`).
4. Apply `<new-agent>/remote-backend` once to create `gs://<new-agent>-tfstate`.
5. Run the pipeline with `productName=<new-agent>`. Names become `<new-agent>-<env>-<resource>`.

Leave `modules/` unchanged.
