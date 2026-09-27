# Trivy config vs tfsec for Terraform

- Date: 2026-09-07
- Status: cited research; **not an ADR** and not a plan
- Scope: IaC misconfiguration scanning for this repository
- Non-goals: GitOps engine choice, Infracost, live AWS mutation, writing `docs/adr/`

## Sources

Primary (Aqua / Trivy / GitHub; fetched 2026-09-07):

- [Aqua tfsec README — “Tfsec is now part of Trivy”](https://github.com/aquasecurity/tfsec)
- [Aqua tfsec → Trivy migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md)
- [Aqua announcement: tfsec is joining the Trivy family (#1994, 2023-02-18)](https://github.com/aquasecurity/tfsec/discussions/1994)
- [tfsec v1.28.14 release (latest, 2025-05-02)](https://github.com/aquasecurity/tfsec/releases/tag/v1.28.14)
- [Trivy Terraform coverage](https://trivy.dev/docs/latest/coverage/iac/terraform/)
- [Trivy misconfiguration scanning](https://trivy.dev/docs/latest/scanner/misconfiguration/)
- [Trivy Terraform tutorial (note to tfsec users)](https://trivy.dev/docs/latest/tutorials/misconfiguration/terraform/)
- [Trivy exit code / `--exit-code`](https://trivy.dev/docs/latest/guide/configuration/others/)
- [Trivy built-in checks bundle](https://trivy.dev/docs/latest/scanner/misconfiguration/check/builtin/)
- [Trivy inline `trivy:ignore:` comments](https://trivy.dev/docs/latest/guide/scanner/misconfiguration/config/config/)
- [Trivy filtering (`.trivyignore`)](https://trivy.dev/docs/latest/guide/configuration/filtering/)
- [Trivy v0.74.0 (latest as of this note, 2026-08-14)](https://github.com/aquasecurity/trivy/releases/tag/v0.74.0)
- [GHSA-69fq-xp46-6x23 — Trivy supply chain, March 2026](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)
- [GHSA-mcj4-mphf-j9ff — path traversal in OCI artifact download, patched 0.71.1](https://github.com/aquasecurity/trivy/security/advisories/GHSA-mcj4-mphf-j9ff)

Related local note (not a source of deprecation): [`docs/research/2026-09-07-harness-engineering-and-checks.md`](./2026-09-07-harness-engineering-and-checks.md).

## Historical repository state on 2026-09-07

[`.mise.toml`](../../.mise.toml) pins:

```toml
terraform = "1.16.1"
tfsec = "1.28.14"
```

No Trivy pin. No mise `[tasks]`. Terraform lives under `platform/` (stubs). `gitops/` is empty.

tfsec **1.28.14 is the current latest tfsec tag** ([releases](https://github.com/aquasecurity/tfsec/releases/tag/v1.28.14)). Changelog for that tag is Go-crypto / linter / `golang.org/x/net` bumps, not a new Terraform check engine.

## 1. Aqua's published direction (source checked 2026-09-07)

Aqua’s own [tfsec README](https://github.com/aquasecurity/tfsec) (repo description: “Tfsec is now part of Trivy”) and pinned [discussion #1994](https://github.com/aquasecurity/tfsec/discussions/1994):

> Going forward we want to encourage the tfsec community to transition over to Trivy. […] tfsec will continue to remain available for the time being, although our engineering attention will be directed at Trivy going forward.

Same wording on the README’s “tfsec to Trivy Migration” section. Trivy’s [Terraform tutorial](https://trivy.dev/docs/latest/tutorials/misconfiguration/terraform/) repeats it under **“A note to tfsec users”** and links #1994.

That is **not** “deleted tomorrow.” It is **maintenance-mode tfsec + active Trivy**. Proof of direction is Aqua’s README + #1994, not third-party blogs.

tfsec still exists and still scans Terraform ([README usage](https://github.com/aquasecurity/tfsec)). New IaC check work and integrations are on Trivy.

## 2. Replacement command

Aqua [migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md):

```text
tfsec <dir>          →  trivy config <dir>
```

Trivy [misconfiguration quick start](https://trivy.dev/docs/latest/scanner/misconfiguration/) and [Terraform tutorial](https://trivy.dev/docs/latest/tutorials/misconfiguration/terraform/): `trivy config` is the IaC command. It auto-detects mixed types (Terraform, CloudFormation, Dockerfile, Kubernetes, Helm) in one directory.

For **this** repo’s required red loop (HCL under `platform/`, fail the gate when findings exist):

```text
trivy config --exit-code 1 platform/
```

tfvars (when they exist):

| Tool | Official flag |
|---|---|
| tfsec | `--tfvars-file` / `--var-file` ([README](https://github.com/aquasecurity/tfsec)) |
| Trivy | `trivy config --tf-vars <file> <dir>` ([Terraform coverage](https://trivy.dev/docs/latest/coverage/iac/terraform/)) |

The migration guide’s `trivy --tf-vars` (no `config` subcommand) is the older shorthand; current Trivy docs use `trivy config --tf-vars`.

`trivy config` does **not** run secret or vulnerability scanners. Secrets + misconfig on a tree: `trivy fs --scanners secret,misconfig ./` ([tutorial](https://trivy.dev/docs/latest/tutorials/misconfiguration/terraform/)). Keep that as a separate, later choice — not the tfsec replacement.

Plan / plan-JSON scan exists (`terraform plan --out tfplan` then `trivy config tfplan`) ([Terraform coverage](https://trivy.dev/docs/latest/coverage/iac/terraform/)). That path needs a working plan (provider APIs, credentials). It is **opt-in**, not a required local loop. Plan JSON cannot always resolve `for_each` / `count` references ([limitation](https://trivy.dev/docs/latest/coverage/iac/terraform/#limitations)).

## 3. Exit codes (red loop vs green theatre)

**tfsec:** “The exit status will be non-zero if tfsec finds problems, otherwise the exit status will be zero.” ([README Usage](https://github.com/aquasecurity/tfsec)). `--soft-fail` is the override that suppresses the error code (CLI `--help` on a local tfsec binary; same flag is documented in tfsec’s flag set).

**Trivy:** “By default, `Trivy` exits with code 0 even when security issues are detected. Use the `--exit-code` option if you want to exit with a non-zero exit code.” Misconfiguration is in the supported table ([exit code docs](https://trivy.dev/docs/latest/guide/configuration/others/)). Config-file default is `exit-code: 0` ([config file](https://trivy.dev/docs/latest/references/configuration/config-file/)).

A `trivy config platform/` job that prints findings and exits 0 is **not** a red loop. The flag that makes it one is `--exit-code 1`.

Severity filter is independent: `trivy config --exit-code 1 --severity HIGH,CRITICAL platform/` still exits 0 when only LOW/MEDIUM remain ([filtering](https://trivy.dev/docs/latest/guide/configuration/filtering/)). Pick the severity list in the ADR; do not assume “any finding” unless `--severity` is left at default (UNKNOWN through CRITICAL).

## 4. Ignore dialects (why dual-running hurts)

| | tfsec | Trivy |
|---|---|---|
| Inline | `#tfsec:ignore:<rule>` ([README](https://github.com/aquasecurity/tfsec)) | `#trivy:ignore:<id>` — AVD id, long id, or alias ([inline comments](https://trivy.dev/docs/latest/guide/scanner/misconfiguration/config/config/)) |
| File | CLI `-e` / config | `.trivyignore` / experimental `.trivyignore.yaml` ([filtering](https://trivy.dev/docs/latest/guide/configuration/filtering/)) |
| Expiry | `:exp:yyyy-mm-dd` | `:exp:yyyy-mm-dd` |

Trivy’s documented inline format is `trivy:ignore:`, not `tfsec:ignore:`. A community comment on #1994 claimed Trivy still honours some tfsec comments; **that is not in current Trivy docs**. Treat ignore migration as a real cost if this repo ever writes `tfsec:ignore:` comments. Today `platform/` is empty, so there is nothing to migrate.

## 5. Checks freshness and network

Trivy’s [built-in checks](https://trivy.dev/docs/latest/scanner/misconfiguration/check/builtin/):

- Checks live in [`aquasecurity/trivy-checks`](https://github.com/aquasecurity/trivy-checks).
- On scan, Trivy downloads an OPA bundle from `ghcr.io/aquasecurity/trivy-checks`, caches it, and refreshes about every 24 hours.
- Embedded checks in the binary are the **fallback** if the pull fails (air-gap / blocked GHCR).
- Misconfiguration scanning therefore wants **network to GHCR** unless you pin/skip updates (`--skip-check-update` / air-gap docs).

tfsec ships its rule set in the binary. That is simpler offline. It is also why tfsec will lag: Aqua is not investing new checks there ([#1994](https://github.com/aquasecurity/tfsec/discussions/1994)).

Pinning the **Trivy CLI** does not freeze the checks bundle unless you also skip the pull. Allowing updates keeps checks fresh; a hermetic CI setup would need to select `--skip-check-update` explicitly.

## 6. Is running both useful?

**Not as two required gates.** Aqua says Trivy **is** the Terraform engine tfsec became ([README](https://github.com/aquasecurity/tfsec), [migration guide](https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md)). Dual required scans mean:

- Duplicate (or near-duplicate) findings
- Two ignore dialects to keep in sync
- Two pins, two failure modes, two “which one is source of truth?” debates
- Extra CI minutes for no extra engine

**Useful only as a short bridge:** keep tfsec 1.28.14 until a Trivy pin exists in `.mise.toml` and `trivy config --exit-code 1 platform/` is the documented check. Then drop tfsec. Do not leave both in `mise run checks`.

Long-term tfsec-only use conflicts with the vendor's direction to move Terraform scanning to Trivy.

## 7. What this repo’s tfsec pin implies

| Fact | Implication |
|---|---|
| Pin is **1.28.14**, which is **latest tfsec** | Not a stale pin; it is the last line of a maintenance-mode tool |
| No Trivy pin | Successor is not in the toolchain yet |
| `platform/` is empty | Ignore-comment migration cost is ~0 if you switch **now** |
| Terraform 1.16.1 is pinned | Scanner must keep working against current HCL; Trivy is the maintained path |

Keeping tfsec 1.28.14 forever is choosing a frozen rule set. Fine as a **bridge**, not as the destination.

## 8. Version-pin advice (Trivy)

Do **not** leave Trivy unpinned or on `latest`.

Floor and avoid-list from Aqua GitHub advisories (not blogs):

| Constraint | Source |
|---|---|
| **Never** Trivy **0.69.4** (malicious GitHub/deb/rpm/GHCR/ECR/Docker Hub `latest` during ~3h on 2026-03-19). Never Docker Hub **0.69.5 / 0.69.6** (~10h on 2026-03-22). | [GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23) |
| Pin **≥ 0.71.1** (path traversal when fetching attacker-controlled OCI artifacts, including `--checks-bundle-repository`). Default Aqua registries are stated as not affected; still take the patch. | [GHSA-mcj4-mphf-j9ff](https://github.com/aquasecurity/trivy/security/advisories/GHSA-mcj4-mphf-j9ff) |
| Current latest at time of this note: **v0.74.0** (2026-08-14, GitHub immutable release). | [v0.74.0](https://github.com/aquasecurity/trivy/releases/tag/v0.74.0) |

Practical pin for this repo (when an ADR accepts Trivy): `.mise.toml` `trivy = "0.74.0"` (or whatever is latest **and ≥ 0.71.1** on the day of the change). Prefer GitHub release checksums / mise’s checksum verification over `curl | sh`. If CI later uses `aquasecurity/trivy-action`, pin the action to a full SHA ([GHSA recommended actions](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)); that is CI work, not this research file.

The March 2026 incident is a reason to **pin and verify**, not a reason to stay on tfsec. tfsec is not getting the check investment; Trivy is.

## 9. Recommendation for this repository

**Required IaC misconfiguration scanner: Trivy `config` only.**

Exact command for the required non-mutating loop:

```text
trivy config --exit-code 1 platform/
```

When `gitops/` has YAML, the same binary can scan it (`trivy config gitops/` or one tree scan). That is a later wiring choice, not a GitOps-tool ADR.

Keep tfsec 1.28.14 only until that Trivy pin and command exist; then remove the tfsec pin. Do not run both as required. Do not put `terraform plan` or `terraform apply` on this gate.

---

---

## Uncertainties / leftover

- The Trivy version recommendation is historical evidence from 2026-09-07; check current releases and advisories when changing the repository pin.
- Whether a given Trivy build still honours leftover `tfsec:ignore:` comments is **undocumented**; do not rely on it.
- `--skip-check-update` vs live GHCR bundle: playground default = allow the pull; hermetic CI would need an extra ADR sentence.
- Plan-JSON scan accuracy for `for_each`/`count` remains limited ([docs](https://trivy.dev/docs/latest/coverage/iac/terraform/#limitations)).
- The version-sensitive claims above reflect sources consulted on 2026-09-07; verify current documentation and advisories before changing the scanner configuration.
