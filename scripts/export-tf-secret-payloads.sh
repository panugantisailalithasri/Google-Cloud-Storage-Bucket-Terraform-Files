#!/usr/bin/env bash
# Build TF_VAR_secret_payloads JSON from ADO-mapped environment variables.
# Handle keys must match Terraform secrets map keys in via-supervisor tfvars.
set -euo pipefail

python3 - <<'PY'
import json
import os
import sys

mapping = {
    "supervisor": os.environ.get("VIA_SUPERVISOR_SECRET", ""),
    "supervisor_session": os.environ.get("VIA_SUPERVISOR_SESSION", ""),
    "supervisor_memory": os.environ.get("VIA_SUPERVISOR_MEMORY", ""),
}
payloads = {key: value for key, value in mapping.items() if value}

if os.environ.get("REQUIRE_SECRET_PAYLOADS", "") == "1":
    missing = [key for key, value in mapping.items() if not value]
    if missing:
        print("Missing ADO secret payloads for: " + ", ".join(missing), file=sys.stderr)
        print("Link variable group via-supervisor-devsecops-secrets-GCP to this pipeline.", file=sys.stderr)
        sys.exit(1)

print(json.dumps(payloads, separators=(",", ":")))
PY
