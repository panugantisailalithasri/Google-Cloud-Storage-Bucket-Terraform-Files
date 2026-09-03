# GCP Cloud Storage bucket (Terraform)

Terraform configuration that creates a Google Cloud Storage bucket in the **freyr-ai** GCP project, with private access, uniform IAM, versioning, and a lifecycle rule that cleans up old object versions.

Remote state is stored in GCS at `gs://terraform-dev-agent/google-cloud-storage-bucket`.

## What it creates

- One Cloud Storage bucket in `freyr-ai` (override with `project_id` if needed)
- Uniform bucket-level access (IAM only; object ACLs are disabled)
- Public access prevention set to `enforced`
- Object versioning enabled by default
- Soft-delete retention of 7 days (recoverable deletes)
- Lifecycle rule that deletes noncurrent versions after 90 days

The bucket is **not** public. Grant access with IAM after apply, for example:

```bash
gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
  --member="user:you@example.com" \
  --role="roles/storage.objectAdmin"
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or later
- Access to GCP project `freyr-ai` with billing enabled
- The Cloud Storage API enabled
- Credentials that can create buckets (`roles/storage.admin` on `freyr-ai`)
- Access to the existing state bucket `terraform-dev-agent` (`roles/storage.objectAdmin` on that bucket)

Authenticate with Application Default Credentials:

```bash
gcloud auth application-default login
gcloud config set project freyr-ai
gcloud services enable storage.googleapis.com
```

## Usage

1. Copy the example variables and set a globally unique bucket name:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   `project_id` defaults to `freyr-ai`. You only need to change `bucket_name`.

2. Initialize Terraform (this configures the GCS backend), review the plan, and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   State is written to `gs://terraform-dev-agent/google-cloud-storage-bucket/default.tfstate`. Do not commit local `.tfstate` files.

3. After apply, Terraform prints the bucket name and `gs://` URL.

To tear the bucket down:

```bash
terraform destroy
```

Destroy fails if the bucket still has objects and `force_destroy` is `false` (the default). Empty the bucket first, or set `force_destroy = true` only in throwaway environments.

## Remote state

| Setting | Value |
| --- | --- |
| Backend | `gcs` |
| Bucket | `terraform-dev-agent` |
| Prefix | `google-cloud-storage-bucket` |

The `terraform-dev-agent` bucket must already exist. Terraform will not create it. After `terraform init`, all `plan` / `apply` / `destroy` operations read and write state in that bucket instead of a local file.

## Git remotes

Push every change to **both** remotes:

```bash
git push origin main
git push github main
```

| Remote | URL |
| --- | --- |
| `origin` | Origin (`freyr-digital/gcp-storage-terraform`) |
| `github` | https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git |

Add the GitHub remote after clone if it is missing:

```bash
git remote add github https://github.com/panugantisailalithasri/Google-Cloud-Storage-Bucket-Terraform-Files.git
```

## Variables

| Name | Description | Default |
| --- | --- | --- |
| `project_id` | GCP project ID | `freyr-ai` |
| `bucket_name` | Globally unique bucket name | *(required)* |
| `region` | Provider default region | `us-central1` |
| `location` | Bucket location (`US`, `EU`, `us-central1`, …) | `US` |
| `storage_class` | `STANDARD`, `NEARLINE`, `COLDLINE`, or `ARCHIVE` | `STANDARD` |
| `versioning_enabled` | Enable object versioning | `true` |
| `force_destroy` | Allow Terraform to delete objects on destroy | `false` |
| `public_access_prevention` | `enforced` or `inherited` | `enforced` |
| `uniform_bucket_level_access` | Use bucket-level IAM | `true` |
| `soft_delete_retention_seconds` | Soft-delete window (`0` disables) | `604800` (7 days) |
| `lifecycle_age_days` | Delete noncurrent versions after N days (`null` skips) | `90` |
| `labels` | Map of labels | `{}` |

## Outputs

- `bucket_name` — created bucket name
- `bucket_url` — `gs://…` URL
- `bucket_self_link` — Cloud Storage API self link
- `location` / `storage_class` — applied settings

## Notes

- Bucket names are a global namespace. If apply fails with a name conflict, choose another `bucket_name`.
