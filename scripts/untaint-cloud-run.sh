#!/usr/bin/env bash
# A failed Cloud Run destroy (deletion_protection) leaves the resource tainted.
# Taint always plans destroy+create of the same service. Untaint it. If it is
# still tainted, drop it from state only (GCP service stays) so import can
# re-attach via-*-prod-run / via-*-devsecops-run.
set -euo pipefail

STACK="${1:?usage: untaint-cloud-run.sh <stack-dir>}"

if ! terraform -chdir="$STACK" state pull >/tmp/tf-state.json 2>/dev/null; then
  echo "No Terraform state yet; nothing to untaint."
  exit 0
fi

mapfile -t ADDRS < <(python3 - "$STACK" <<'PY'
import json
import sys

with open("/tmp/tf-state.json", encoding="utf-8") as handle:
    state = json.load(handle)

for res in state.get("resources", []):
    if res.get("mode") != "managed" or res.get("type") != "google_cloud_run_v2_service":
        continue
    module = res.get("module")
    addr = f"{module}.{res['type']}.{res['name']}" if module else f"{res['type']}.{res['name']}"
    for inst in res.get("instances", []):
        tainted = inst.get("status") == "tainted" or inst.get("tainted") is True
        if tainted:
            print(addr)
PY
)

if [ "${#ADDRS[@]}" -eq 0 ]; then
  echo "No tainted Cloud Run services in state."
  exit 0
fi

for addr in "${ADDRS[@]}"; do
  echo "Untainting ${addr} (GCP Cloud Run is not deleted)."
  if ! terraform -chdir="$STACK" untaint "$addr"; then
    echo "Untaint failed; removing ${addr} from state only so apply can import the live service."
    terraform -chdir="$STACK" state rm "$addr"
  fi
done
