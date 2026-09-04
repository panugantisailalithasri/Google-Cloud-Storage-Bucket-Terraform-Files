# Agent notes

- Reusable modules live in `modules/` (gcs-bucket, iam, secret-manager, cloud-run). Do not run Terraform there.
- Each agent/microservice has its own root folder (example: `via-supervisor/`). Env values live in `<agent>/environments/`.
- via-supervisor deploys Cloud Storage + Secret Manager only (one application bucket). Bucket count is `var.buckets` (`for_each` on `modules/gcs-bucket`); another agent can pass two keys without changing the module.
- Each agent has a dedicated GCS remote-backend bucket named `<product_name>-tfstate` (example: `via-supervisor-tfstate`). Env isolation is the backend prefix (`dev` / `prod`). Create the bucket once from `<agent>/remote-backend/` before the first agent `terraform init`.
- Resource names follow `<product_name>-<environment>-<resource>` (example: `via-supervisor-prod-bucket`).
- All agent stack variable values come from `<agent>/environments/<env>.tfvars` (no defaults in `variables.tf`). Remote-backend values come from `<agent>/remote-backend/terraform.tfvars`.
- GCP `project_id`, region, and location are set in those tfvars files (`freyr-ai`, `us-east1` for via-supervisor).
- After every commit, push `main` to **both** remotes: `origin` and `github` (`https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git`).
- Do not commit secrets, PATs, `.tfstate`, `.terraform.lock.hcl`, or `*.tfvars` (keep `*.tfvars.example`).
- Run `./scripts/scan.sh` (Checkov) after Terraform changes.
