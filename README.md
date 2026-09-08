# Freyr-AI Terraform

Reusable Terraform modules and application stacks for GCP infrastructure.

## Repository layout

```text
modules/
  gcs_bucket/
  cloudsql_postgres/

microservice/
  agent/
    via-supervisor/
      main.tf
      variables.tf
      outputs.tf
      providers.tf
      versions.tf
      dev.tfvars.example
```

## What is implemented now

### Reusable modules

- `modules/gcs_bucket`
  - regional GCS bucket
  - uniform bucket-level access
  - inherited public access prevention
  - optional extra IAM members
  - soft delete retention

- `modules/cloudsql_postgres`
  - PostgreSQL Cloud SQL instance
  - private IP over an existing VPC
  - reusable edition, tier, disk, SSL mode, and label settings

### via-supervisor stack

`microservice/agent/via-supervisor/main.tf` calls both reusable modules:

- GCS bucket module
- Cloud SQL PostgreSQL module

The environment-specific values are defined in the tfvars file:

- `microservice/agent/via-supervisor/dev.tfvars.example`

That file currently uses the VPC requested for private resources:

- `freya-ai-dev-vpc`

## Cloud SQL settings captured from the reference screenshots

The `via-supervisor` stack is configured to match the reference Cloud SQL instance as closely as Terraform allows:

- instance name: `via-supervisor-devsecops-east4`
- region: `us-east4`
- engine: `POSTGRES_18`
- edition: `ENTERPRISE`
- machine type: `db-custom-1-3840`
- availability: `ZONAL`
- storage: `PD_SSD`, 10 GB, autoresize enabled
- connectivity: private IP only
- VPC: `freya-ai-dev-vpc`
- SSL mode: `ALLOW_UNENCRYPTED_AND_ENCRYPTED`
- point-in-time recovery: disabled
- deletion protection: disabled
- data cache: effectively disabled by using `ENTERPRISE` with a custom tier

## How to use locally

```bash
git clone <your-github-repo-url>
cd <repo>/microservice/agent/via-supervisor
cp dev.tfvars.example dev.tfvars
# update project_id and the bucket name if needed

gcloud auth application-default login
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Notes

- keep environment-specific values in tfvars files
- keep reusable logic inside `modules/`
- for any resource that needs VPC connectivity, use the appropriate environment VPC name in the stack tfvars file
