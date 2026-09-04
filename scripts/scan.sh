#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v checkov >/dev/null 2>&1; then
  python3 -m pip install --user --quiet checkov
  export PATH="$HOME/.local/bin:$PATH"
fi

checkov -d modules -d infra --config-file .checkov.yaml "$@"
