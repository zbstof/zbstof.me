#!/bin/bash
# Plan (and optionally apply) the site: buckets, website config and web/ files.
# Usage: scripts/deploy-site.sh [--apply]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/terraform"

terraform init -input=false
terraform plan -input=false -out=tfplan

if [ "${1:-}" = "--apply" ]; then
  terraform apply -input=false tfplan
  echo
  terraform output
else
  echo
  echo "Plan written to terraform/tfplan. Apply with: scripts/deploy-site.sh --apply"
fi
