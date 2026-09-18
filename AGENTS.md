# Agent notes

- Reusable modules live in `modules/` (gcs-bucket, iam, secret-manager, cloud-run, cloud-sql). Do not run Terraform there.
- Each agent/microservice has its own root folder (example: `via-supervisor/`). Env values live in `<agent>/environments/`.
- via-supervisor deploys the DSO stack in `freyr-ai` / `us-east4`: Cloud Run, one config bucket, three secrets, two Cloud SQL instances (existing `via-supervisor-devsecops-east4` sessions + new `via-supervisor-devsecops-memory-sql` pgvector). Superagent is a separate folder.
- Each agent has a dedicated GCS remote-backend bucket named `<product_name>-tfstate` (example: `via-supervisor-tfstate`). Env isolation is the backend prefix (`dev` / `prod`). Create the bucket once from `<agent>/remote-backend/` before the first agent `terraform init`.
- Resource names are composed in Terraform as `<product_name>-<environment>-<resource>` (example: `via-supervisor-prod-bucket`). `product_name` and `environment` come from tfvars / pipeline `productName`; each resource supplies only a suffix (`sa`, `bucket`, `run`, `sql`). Do not hardcode full GCP names in tfvars.
- All agent stack variable values come from `<agent>/environments/<env>.tfvars` (no defaults in `variables.tf`). Remote-backend values come from `<agent>/remote-backend/terraform.tfvars`.
- GCP `project_id`, region, and location are set in those tfvars files (`freyr-ai`, `us-east4` for via-supervisor DSO).
- After every commit, push `main` to **both** remotes: `origin` and `github` (`https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git`).
- Do not commit secrets, PATs, `.tfstate`, `.terraform.lock.hcl`, or `*.tfvars` (keep `*.tfvars.example`).
- Azure DevOps authenticates to GCP with ARM service connection `GCP_freyrai_service_role` and Workload Identity Federation (`ado-deployer-v3@freyr-ai.iam.gserviceaccount.com`). Do not use a GCP JSON key in the pipeline.
