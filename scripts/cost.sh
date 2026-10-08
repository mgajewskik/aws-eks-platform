#!/usr/bin/env bash
# Opt-in Infracost scan, skipped while docs/cost.md records the current price fingerprint.
# Usage: cost.sh [refresh|--check|--print-fingerprint]. --check never calls Infracost. Auth comes from .env.local; never print it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Only lines that can change price feed the fingerprint. A fixed collation keeps it identical across machines and CI.
PATTERN='resource[[:space:]]+"aws_|instance_type|instance_class|desired_size|desired_capacity|min_size[[:space:]]*=|max_size[[:space:]]*=|volume_size|disk_size|allocated_storage|single_nat_gateway|enable_nat_gateway|retention_in_days|multi_az|instance_count|capacity_type|count[[:space:]]*=|for_each|LoadBalancer|storageClassName|instanceType'
fingerprint() {
  { grep -rEH --exclude-dir=.terraform --include='*.tf' --include='*.tfvars' --include='*.yml' --include='*.yaml' \
      "$PATTERN" platform $([[ -d gitops ]] && echo gitops) || true; } | LC_ALL=C sort | sha256sum | cut -d' ' -f1
}

case "${1:-}" in
  --print-fingerprint) fingerprint; exit ;;
  "" | refresh | --check) ;;
  *) echo "usage: cost.sh [refresh|--check|--print-fingerprint]" >&2; exit 2 ;;
esac
current=$(fingerprint)
if [[ ${1:-} == --check ]]; then
  grep -qx -- "- Fingerprint: $current" docs/cost.md || { echo "cost: docs/cost.md is stale; run mise run cost" >&2; exit 1; }
  exit
fi
if [[ ${1:-} != refresh ]] && grep -qx -- "- Fingerprint: $current" docs/cost.md; then
  echo "cost: cache hit $current; totals are in docs/cost.md"
  exit
fi
echo "cost: cache miss $current; calling infracost once"
infracost scan platform
echo "cost: record fingerprint $current with the new totals in docs/cost.md"
