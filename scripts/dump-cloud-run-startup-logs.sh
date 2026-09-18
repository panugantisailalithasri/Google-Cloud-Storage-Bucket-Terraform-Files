#!/usr/bin/env bash
# Print Cloud Run revision stderr/stdout after a failed apply so ADO shows
# why the container never listened on PORT (not the Terraform wrapper error).
set -u

PRODUCT="${1:-}"
PIPELINE_ENV="${2:-dev}"
PROJECT="${3:-freyr-ai}"
REGION="${4:-us-east4}"

if [ -z "$PRODUCT" ]; then
  echo "usage: $0 <productName> [dev|prod] [project] [region]" >&2
  exit 1
fi

if [ "$PIPELINE_ENV" = "prod" ]; then
  TF_ENV="prod"
else
  TF_ENV="devsecops"
fi

SERVICE="${PRODUCT}-${TF_ENV}-run"
BUCKET="${PRODUCT}-${TF_ENV}-bucket"

echo "===== Cloud Run service ${SERVICE} ====="
gcloud run services describe "$SERVICE" \
  --project="$PROJECT" \
  --region="$REGION" \
  --format='yaml(status.conditions,status.latestCreatedRevisionName,spec.template.spec.containers[0].ports,spec.template.spec.containers[0].image)' \
  || echo "Service ${SERVICE} not found (create failed)."

echo
echo "===== Recent revision logs (last 1h) ====="
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE}" \
  --project="$PROJECT" \
  --limit=80 \
  --freshness=1h \
  --format='value(timestamp,textPayload,jsonPayload.message,jsonPayload)' \
  || echo "Could not read logs."

echo
echo "===== GCS config object (composed bucket) ====="
gcloud storage ls "gs://${BUCKET}/**" 2>/dev/null || echo "Bucket ${BUCKET} missing or empty."
