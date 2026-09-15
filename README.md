# GCP Terraform for agents and microservices

Reusable **modules** for Cloud Storage, IAM, Secret Manager, Cloud Run, and Cloud SQL. Each **agent / microservice** has its own folder (starting with `via-supervisor`). Environment values live under that folder in `environments/`. Each agent has a **dedicated Terraform state bucket**.

**via-supervisor** deploys the DSO footprint in `freyr-ai` / `us-east4`: two Cloud Run services, two config buckets, six secrets, three Cloud SQL instances, on VPC `freya-ai-dev-vpc`. All values come from `environments/*.tfvars`.

## Layout

```
modules/                         Reusable GCP templates (do not run Terraform here)
  gcs-bucket/
  iam/
  secret-manager/
  cloud-run/
  cloud-sql/

via-supervisor/                  DSO stack for VIA supervisor + superagent
  remote-backend/                Creates gs://via-supervisor-tfstate (run once)
  environments/
    dev.tfvars.example           DSO/dev values
    prod.tfvars.example          DSO/prod values
  main.tf                        Calls the modules
```

## DSO resources (from tfvars)

| Kind | Names |
| --- | --- |
| Cloud Run | `via-supervisor-dso`, `via-superagent-dso` |
| Service accounts | `via-supervisor-dso-sa`, `via-superagent-dso-sa` |
| GCS | `via-supervisor-config-dso`, `via-superagent-config-dso` |
| Secrets | `via-supervisor-dso-secret`, `via-supervisor-session-dso-secret`, `via-supervisor-memory-service-dso-secret`, `via-superagent-dso-secret`, `via-superagent-session-dso-secret`, `via-cognito-m2m-dso` |
| Cloud SQL | `via-supervisor-sql-dso`, `via-superagent-sql-dso`, `via-supervisor-memory-sql-dso` |
| VPC / subnet | `freya-ai-dev-vpc` / `freya-ai-dev-subnet-us-east4` |

Supervisor Cloud Run allows `allUsers` invoke because Cognito OAuth is enforced in the app. Superagent invoke is limited to the supervisor service account. GCS JSON config objects are not uploaded by Terraform.

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

ADO sets `bucket=$(productName)-tfstate` and `prefix=$(environment)` automatically. Pipeline variables also record DSO project `freyr-ai`, region `us-east4`, VPC `freya-ai-dev-vpc`, and subnet `freya-ai-dev-subnet-us-east4`.

## Naming convention

```text
<product_name>-<environment>-<resource>
```

DSO names are set explicitly in tfvars (not derived as `<product>-<env>-<resource>`):

| Resource | Name |
| --- | --- |
| Supervisor Cloud Run | `via-supervisor-dso` |
| Superagent Cloud Run | `via-superagent-dso` |
| Config buckets | `via-supervisor-config-dso`, `via-superagent-config-dso` |
| Remote backend | `via-supervisor-tfstate` (prefix `dev` or `prod`) |

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
