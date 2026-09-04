# Agent notes

- Reusable modules live in `modules/` (gcs-bucket, iam, secret-manager, cloud-run). Do not run Terraform there.
- Each agent/microservice has its own root folder (example: `via-supervisor/`). Env values live in `<agent>/environments/`.
- Each agent has a dedicated GCS remote-backend bucket named `<product_name>-tfstate` (example: `via-supervisor-tfstate`). Env isolation is the backend prefix (`dev` / `prod`). Create the bucket once from `<agent>/remote-backend/` before the first agent `terraform init`.
- Resource names follow `<product_name>-<environment>-<resource>` (example: `via-supervisor-prod-bucket`).
- GCP `project_id` defaults to `freyr-ai`. Region/location default to `us-east1`.
- After every commit, push `main` to **both** remotes: `origin` and `github` (`https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git`).
- Do not commit secrets, PATs, `.tfstate`, `.terraform.lock.hcl`, or `*.tfvars` (keep `*.tfvars.example`).
- Run `./scripts/scan.sh` (Checkov) after Terraform changes.
