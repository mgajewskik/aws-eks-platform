#!/usr/bin/env bash
# Opt-in cost estimate. Cache key is the price fingerprint in docs/cost.md.
# Auth, when used, comes from .env.local (INFRACOST_CLI_AUTHENTICATION_TOKEN).
# mise loads that file for the whole repo. This pin is infracost/cli 2.16.3.
# This script never prints the key.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COST_DOC="$ROOT/docs/cost.md"
PATTERN='resource[[:space:]]+"aws_|instance_type|instance_class|desired_size|desired_capacity|min_size[[:space:]]*=|max_size[[:space:]]*=|volume_size|disk_size|allocated_storage|single_nat_gateway|enable_nat_gateway|retention_in_days|multi_az|instance_count|capacity_type|count[[:space:]]*=|for_each|LoadBalancer|storageClassName|instanceType'

fingerprint() {
  local tmp file rel
  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  : >"$tmp"
  while IFS= read -r -d '' file; do
    rel="${file#"$ROOT"/}"
    grep -E "$PATTERN" "$file" | sed "s|^|${rel}:|" >>"$tmp" || true
  done < <(
    {
      [[ -d "$ROOT/platform" ]] && find "$ROOT/platform" -type f \( -name '*.tf' -o -name '*.tfvars' \) -print0
      [[ -d "$ROOT/gitops" ]] && find "$ROOT/gitops" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0
    } | sort -z
  )
  sort -o "$tmp" "$tmp"
  sha256sum "$tmp" | awk '{print $1}'
}

recorded_fingerprint() {
  if [[ ! -f "$COST_DOC" ]]; then
    return 0
  fi
  grep -E '^[[:space:]]*- Fingerprint: ' "$COST_DOC" | head -n 1 | sed 's/.*Fingerprint:[[:space:]]*//'
}

force=0
case "${1:-}" in
  "") ;;
  refresh) force=1 ;;
  --print-fingerprint)
    fingerprint
    exit 0
    ;;
  *)
    echo "usage: cost.sh [refresh|--print-fingerprint]" >&2
    exit 2
    ;;
esac

current="$(fingerprint)"
recorded="$(recorded_fingerprint || true)"

if [[ "$force" -eq 0 && -n "$recorded" && "$recorded" == "$current" ]]; then
  echo "cost: cache hit ${current}"
  echo "cost: infracost not called; totals in $COST_DOC"
  exit 0
fi

if ! command -v infracost >/dev/null 2>&1; then
  echo "cost: infracost is not on PATH. Run mise install, then mise run cost." >&2
  exit 1
fi

echo "cost: cache miss ${current}"
if [[ -z "${INFRACOST_CLI_AUTHENTICATION_TOKEN:-}" ]]; then
  echo "cost: no INFRACOST_CLI_AUTHENTICATION_TOKEN in this process. Put it in .env.local, or run infracost auth login." >&2
fi
echo "cost: calling infracost once"
infracost scan "$ROOT/platform"
echo "cost: fingerprint ${current}"
echo "cost: write this fingerprint into docs/cost.md with the new totals before the next run"
