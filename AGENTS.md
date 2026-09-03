# Agent notes

- GCP `project_id` defaults to `freyr-ai`. Do not revert that unless asked.
- Terraform remote state is the GCS backend in `backend.tf`: bucket `terraform-dev-agent`, prefix `google-cloud-storage-bucket`.
- After every commit, push `main` to **both** remotes: `origin` (Origin) and `github` (https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git). Add the `github` remote if it is missing.
- Do not commit secrets, PATs, `.tfstate`, or `terraform.tfvars`.
