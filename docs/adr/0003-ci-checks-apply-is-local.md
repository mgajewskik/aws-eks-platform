---
status: accepted
date: 2026-09-07
---

# GitHub Actions runs checks; apply stays on the laptop

## Context and Problem Statement

This repo will use GitHub Actions. Terraform apply can create billed AWS resources. The working copy of environment parameters may include an AWS account ID the owner does not want in CI.

## Considered Options

* CI plans and applies via OIDC
* CI runs `mise run checks` only; apply/destroy are laptop, human-run, opt-in
* No CI

## Decision Outcome

Chosen option: "CI runs `mise run checks` only", because the required loops are local and non-mutating, and apply from the laptop keeps AWS credentials and any later decrypt keys off GitHub runners.

GitHub Actions must not receive AWS apply credentials, a GPG/SOPS private key, or the real `dev.tfvars`. `terraform apply` / `destroy` stay opt-in, never part of `mise run checks`.

Amendment, 2026-09-27: ADR-0004 supersedes the exclusion of non-secret environment tfvars and account identifiers. CI may read committed parameters. Secret values and local credential files remain excluded. All deployments and teardown remain owner-run on the local machine.

CI stays one job: prepare the pinned check tools and uv-locked Python environment, then run `mise run checks`. All tests use pytest. The workflow has read-only repository permissions and no AWS or Infracost credentials. Cost estimation and live scenarios are not CI steps.

### Consequences

* Good, because a compromised workflow cannot apply infrastructure.
* Good, because CI can run on a public repo without account-ID or secret material.
* Bad, because drift and apply discipline depend on the laptop; there is no automated apply on merge.

### Confirmation

* `.github/workflows` invoke `mise run checks` (or equivalent) and do not invoke `terraform apply`.
* No AWS apply role or GPG private key is configured for GitHub Actions in this decision.
