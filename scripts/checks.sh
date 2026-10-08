#!/usr/bin/env bash
# Required credential-free checks, run locally and in CI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Throwaway metadata leaves the owner's initialized backend untouched; providers are cached across runs.
TF_DATA_DIR="$(mktemp -d)"
export TF_DATA_DIR
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.cache/terraform/plugins}"
trap 'rm -rf "$TF_DATA_DIR"' EXIT
mkdir -p "$TF_PLUGIN_CACHE_DIR"

echo "== pytest ==" && uv run --locked --no-sync --no-env-file pytest
echo "== terraform ==" && terraform fmt -check -recursive platform
terraform -chdir=platform init -backend=false -input=false -no-color >/dev/null
terraform -chdir=platform validate -no-color
echo "== tflint ==" && tflint --chdir=platform --config="$PWD/.tflint.hcl" --recursive
echo "== trivy ==" && trivy config --exit-code 1 --tf-vars platform/default.tfvars platform/
if [[ -d gitops ]]; then trivy config --exit-code 1 gitops/; fi
trivy fs --scanners secret --exit-code 1 . # skip lists in trivy.yaml
