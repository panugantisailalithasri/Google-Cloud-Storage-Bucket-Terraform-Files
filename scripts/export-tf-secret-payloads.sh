#!/usr/bin/env bash
# Write a Terraform JSON var-file with secret_payloads from ADO-mapped env vars.
# Handle keys must match Terraform secrets map keys in the agent tfvars.
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <secret_payloads.tfvars.json>" >&2
  exit 1
fi
OUT="$1"

python3 - "$OUT" <<'PY'
import json
import os
import sys

out_path = sys.argv[1]
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
        print(f"Link variable group {group} to this pipeline and authorize it for the Apply environment.", file=sys.stderr)
        sys.exit(1)

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump({"secret_payloads": payloads}, handle, separators=(",", ":"))

print(f"Wrote {len(payloads)} secret payload(s) for keys: {', '.join(sorted(payloads))}")
PY

chmod 600 "$OUT"
