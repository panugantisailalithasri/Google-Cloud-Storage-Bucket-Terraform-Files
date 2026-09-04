# Agent notes

- GCP `project_id` defaults to `freyr-ai`. Region/location default to `us-east1`.
- Reusable modules live in `modules/` (gcs-bucket, iam, secret-manager, cloud-run). Composition is `infra/`.
- Resource names follow `<product_name>-<environment>-<resource>` (example: `via-supervisor-prod-bucket`). Pass product, env, and the resource suffix as variables; never hardcode the full name.
- Terraform state backend is GCS bucket `terraform-dev-agent`. Prefix is `<product_name>/<environment>` via `-backend-config`.
- After every commit, push `main` to **both** remotes: `origin` and `github` (`https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git`).
- Do not commit secrets, PATs, `.tfstate`, `.terraform.lock.hcl`, or `terraform.tfvars`.
- Run `./scripts/scan.sh` (Checkov) after Terraform changes and keep the ADO Validate stage green.
