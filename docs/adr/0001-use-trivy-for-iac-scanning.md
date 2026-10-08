---
status: accepted
date: 2026-09-07
---

# Use Trivy config scanning instead of tfsec

## Context and Problem Statement

This repo needs a required, non-mutating IaC misconfiguration check that fails on real findings. `.mise.toml` already pins `tfsec` 1.28.14. Aqua Security, which owns both tools, has moved Terraform scanning into Trivy and is not investing new check work in tfsec.

## Considered Options

* tfsec only (keep the current pin)
* Trivy config only (`trivy config --exit-code 1 platform/`)
* Run both as required gates

## Decision Outcome

Chosen option: "Trivy config only", because Aqua's own tfsec README and migration guide tell users to switch (`tfsec <dir>` → `trivy config <dir>`), Trivy is the maintained engine, and `platform/` is still empty so there are no `tfsec:ignore` comments to migrate.

Required command: `trivy config --exit-code 1 platform/`. Pin Trivy in `.mise.toml` at ≥ 0.71.1 (never 0.69.4). Drop the tfsec pin once that command is in `mise run checks`. Do not run both scanners as required gates.

### Consequences

* Good, because the required scanner is the one Aqua is actively updating, including Kubernetes/YAML later under `gitops/`.
* Good, because `--exit-code 1` makes findings a real red loop (Trivy otherwise exits 0).
* Bad, because Trivy pulls the checks bundle from GHCR unless `--skip-check-update` is set, so a pin of the CLI is not a pin of the policies.
* Bad, because ignore comments use `trivy:ignore:` / AVD ids, not `tfsec:ignore:`.

### Confirmation

* `.mise.toml` pins `trivy` and does not pin `tfsec`.
* `mise run checks` includes `trivy config --exit-code 1 platform/` and does not invoke tfsec.

## More Information

* [Aqua tfsec README](https://github.com/aquasecurity/tfsec)
* [tfsec → Trivy migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md)
* [Announcement #1994](https://github.com/aquasecurity/tfsec/discussions/1994)
* [Trivy exit-code docs](https://trivy.dev/docs/latest/guide/configuration/others/)
