#!/usr/bin/env bash
# If state still tracks via-supervisor-devsecops-east4 as module.sql["sql"],
# drop it (and its databases) without destroying the GCP instance so apply
# can create via-supervisor-devsecops-sql.
set -euo pipefail

STACK="${1:-via-supervisor}"
ADDR='module.sql["sql"].google_sql_database_instance.this'

if ! terraform -chdir="$STACK" state list 2>/dev/null | grep -F "$ADDR" >/dev/null; then
  echo "No ${ADDR} in state; nothing to drop."
  exit 0
fi

NAME="$(terraform -chdir="$STACK" state show "$ADDR" | awk -F'"' '/^[[:space:]]*name[[:space:]]*=/ { print $2; exit }')"

if [ "$NAME" != "via-supervisor-devsecops-east4" ]; then
  echo "State sql instance is '${NAME}'; leaving state unchanged."
  exit 0
fi

echo "Removing via-supervisor-devsecops-east4 from Terraform state (GCP instance is not deleted)."
terraform -chdir="$STACK" state rm \
  'module.sql["sql"].google_sql_database_instance.this' \
  'module.sql["sql"].google_sql_database.this["ff-freya-supervisor-pac-adk"]' \
  'module.sql["sql"].google_sql_database.this["ff-freya-supervisor-pac-langgraph"]' \
  || true
