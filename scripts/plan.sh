#!/usr/bin/env bash
# Owner-run plan. platform/tfplan exists only when the plan policy passed, so
# `mise run apply` applies exactly what was verified. Extra arguments go to
# terraform plan, for example -destroy or -replace=<address>.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
umask 077 # plan files hold sensitive values in plain text

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
rm -f platform/tfplan

terraform -chdir=platform plan -var-file=default.tfvars -input=false -out="$work/tfplan" "$@"
terraform -chdir=platform show -json "$work/tfplan" >"$work/tfplan.json"
python3 scripts/plan_policy.py "$work/tfplan.json"
mv "$work/tfplan" platform/tfplan
echo "plan: saved platform/tfplan; mise run apply applies exactly this plan"
