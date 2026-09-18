#!/usr/bin/env bash
# Build TF_VAR_secret_payloads JSON from ADO-mapped environment variables.
# Handle keys must match Terraform secrets map keys in the agent tfvars.
set -euo pipefail

python3 - <<'PY'
import json
import os
import sys

product = os.environ.get("PRODUCT_NAME", "")

if product == "via-supervisor":
    mapping = {
        "supervisor": os.environ.get("VIA_SUPERVISOR_SECRET", ""),
        "supervisor_session": os.environ.get("VIA_SUPERVISOR_SESSION", ""),
        "supervisor_memory": os.environ.get("VIA_SUPERVISOR_MEMORY", ""),
    }
    group = "via-supervisor-devsecops-secrets-GCP"
elif product == "via-superagent":
    mapping = {
        "superagent": os.environ.get("VIA_SUPERAGENT_SECRET", ""),
        "superagent_session": os.environ.get("VIA_SUPERAGENT_SESSION", ""),
        "cognito": os.environ.get("VIA_SUPERAGENT_COGNITO", ""),
    }
    group = "via-superagent-devsecops-secrets-GCP"
else:
    print("PRODUCT_NAME must be via-supervisor or via-superagent", file=sys.stderr)
    sys.exit(1)

payloads = {key: value for key, value in mapping.items() if value}

if os.environ.get("REQUIRE_SECRET_PAYLOADS", "") == "1":
    missing = [key for key, value in mapping.items() if not value]
    if missing:
        print("Missing ADO secret payloads for: " + ", ".join(missing), file=sys.stderr)
        print(f"Link variable group {group} to this pipeline.", file=sys.stderr)
        sys.exit(1)

print(json.dumps(payloads, separators=(",", ":")))
PY
