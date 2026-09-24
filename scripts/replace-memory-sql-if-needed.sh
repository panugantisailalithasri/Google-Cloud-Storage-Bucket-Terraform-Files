#!/usr/bin/env bash
# Cloud SQL cannot shrink disk or always convert edition in place.
# If via-supervisor-devsecops-memory-sql is already in state and is not
# 53 GB ENTERPRISE, print -replace addresses so apply deletes it and
# creates a new instance (same name). No-op when the instance is absent
# or already matches. Does not touch the sessions instance.
set -euo pipefail

STACK="${1:-via-supervisor}"
ADDR='module.sql["memory_sql"].google_sql_database_instance.this'

if ! terraform -chdir="$STACK" state list 2>/dev/null | grep -F "$ADDR" >/dev/null; then
  exit 0
fi

SHOW="$(terraform -chdir="$STACK" state show "$ADDR")"
DISK="$(printf '%s\n' "$SHOW" | awk '/^[[:space:]]*disk_size[[:space:]]*=/ { print $3; exit }')"
EDITION="$(printf '%s\n' "$SHOW" | awk -F'"' '/^[[:space:]]*edition[[:space:]]*=/ { print $2; exit }')"

if [ "${DISK:-}" = "53" ] && [ "${EDITION:-}" = "ENTERPRISE" ]; then
  echo "memory-sql already ${DISK} GB ${EDITION}; not replacing." >&2
  exit 0
fi

echo "memory-sql in state is disk=${DISK:-unknown} edition=${EDITION:-unknown}; replacing so apply creates 53 GB ENTERPRISE." >&2

terraform -chdir="$STACK" state list | grep -F 'module.sql["memory_sql"]' || true
