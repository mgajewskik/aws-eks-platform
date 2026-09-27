#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== harness tests =="
uv run --locked --no-sync --no-env-file pytest

has_tf_content=0
if find platform -name '*.tf' -type f -size +0c -print -quit 2>/dev/null | grep -q .; then
  has_tf_content=1
fi

echo "== terraform fmt =="
terraform fmt -check -recursive platform

if [[ "$has_tf_content" -eq 1 ]]; then
  echo "== terraform validate =="
  (
    cd platform
    terraform init -backend=false -input=false -no-color >/dev/null
    terraform validate -no-color
  )

  echo "== tflint =="
  # terraform language ruleset is bundled; --init is only needed for extra plugins (e.g. AWS)
  (cd platform && tflint --config "$ROOT/.tflint.hcl" --recursive)
else
  echo "== terraform validate =="
  echo "skip: no non-empty .tf files under platform/"
  echo "== tflint =="
  echo "skip: no non-empty .tf files under platform/"
fi

echo "== trivy config =="
trivy config --exit-code 1 platform/

if [[ -d gitops ]] && find gitops -type f \( -name '*.yaml' -o -name '*.yml' \) -print -quit | grep -q .; then
  echo "== trivy gitops config =="
  trivy config --exit-code 1 gitops/
else
  echo "skip: no GitOps YAML under gitops/"
fi

echo "== trivy secrets =="
# Scan project files, excluding local credentials, state, and runtime artifacts.
trivy fs --scanners secret --exit-code 1 \
  --skip-dirs '**/.git' --skip-dirs '**/.codex' \
  --skip-dirs '**/.terraform' --skip-dirs '**/__pycache__' \
  --skip-dirs '**/.venv' --skip-dirs '**/.pytest_cache' \
  --skip-files '**/.env*' --skip-files '**/*.secret.tfvars' \
  --skip-files '**/*.tfstate*' --skip-files '**/*.tfplan' .
