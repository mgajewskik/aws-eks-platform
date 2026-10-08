# Terraform lifecycle tasks through mise

**Status:** done
**Loop candidate:** no
**Date:** 2026-09-30

## Goal

The owner can run Terraform init, plan, apply, and destroy from the repository root through `mise run` after completing the existing backend preflight. Init reads its backend settings from `backend.s3.hcl` and uses `-reconfigure`; the same command can be reused whenever initialization is needed. Reusable public AWS settings live in mise env. Plan displays changes in the terminal; apply generates and applies a fresh plan without a confirmation prompt. Destroy also runs without a confirmation prompt. No task saves or requires a Terraform plan file.

### Success criteria

- [x] C1: `mise run plan` invokes `terraform -chdir=platform plan -var-file=default.tfvars`, displaying a speculative plan without an output file. Verify with mise dry-run and installed Terraform plan help.
- [x] C2: `mise run apply` invokes `terraform -chdir=platform apply -var-file=default.tfvars -auto-approve`, applying a fresh plan without a confirmation prompt or a saved plan file. Verify with mise dry-run and installed Terraform apply help.
- [x] C3: `mise run destroy` invokes `terraform -chdir=platform destroy -var-file=default.tfvars -auto-approve`, deleting resources without a confirmation prompt. Verify with mise dry-run and installed Terraform help.
- [x] C4: README, task descriptions, and runbook describe reusable init, backend file ownership, reconfigure semantics, failure boundaries, terminal planning, automatic approval, preflight, teardown impact, and verification. The runbook separates review of a speculative plan from apply/destroy and states that the fresh execution plan can differ. No manual init or BACKEND_REGION assignment remains in the active procedure. Inspect docs and run the docs gate.
- [x] C5: `mise run init` invokes exactly `terraform -chdir=platform init -reconfigure -backend-config=backend.s3.hcl`, with no AWS discovery command or additional backend override. Verify with mise dry-run and installed Terraform init help.
- [x] C6: `platform/backend.s3.hcl` includes the owner-confirmed bucket Region so initialization does not require a separate command or Region override. Verify owner confirmation and current file; never infer it from the platform Region.
- [x] C7: `.mise.toml` declares reusable public `AWS_REGION`, `AWS_DEFAULT_REGION`, and `AWS_ACCOUNT_ID` matching existing platform parameters. Backend-specific bucket/key/Region remain in the backend file. Credentials remain outside tracked configuration; no private env file or credential values are read. Verify parsed public config, source contracts, and security scans.

### Anti-criteria

- [x] A1: No owner-run init or lifecycle task runs through checks, CI, or a task dependency, and no actual AWS lookup or backend initialization runs during validation. No HeadBucket discovery remains in init. Existing check-only `init -backend=false` is unchanged. Inspect task definitions, checks, CI, and validation commands.
- [x] A2: No automatic init through other tasks, tool installation, `-upgrade`, state migration, force-copy, disabled locking, plan-file output/input, backend bucket/key/locking change, tfvars change, or infrastructure edit is added. The owner explicitly accepted the existing `-auto-approve` flags for apply/destroy; no further approval bypass is added. Inspect the commit-preparation diff against its baseline.
- [x] A3: Preserve all pre-existing tracked and untracked work outside the requested init task and its docs/tests. Compare scoped files against the task-start snapshot and inspect Git status.

## Context & References

- `.mise.toml`: existing pinned tools, task auto-install disabled, and owner-run access tasks.
- `docs/runbooks/vpc-bastion.md`: backend preflight, deployment, and teardown procedure.
- `README.md`: owner-facing deployment entrypoint.
- `scripts/checks.sh`, `tests/harness/test_checks.py`: credential-free checks exclude lifecycle operations.
- Local mise `2026.9.14` run help provides task dry-run; local Terraform `1.16.1` plan/apply help confirms speculative planning without `-out` and interactive apply without a plan-file argument.
- Task-start snapshot: `/tmp/terraform-mise-baseline-x07wfjuq`, containing `.mise.toml`, README, runbook, HEAD, and staged/unstaged/untracked status. All existing changes are pre-existing work; this plan is new.
- Amendment baseline: `/tmp/terraform-terminal-baseline-bqmx5jjh`, containing all four scoped files, HEAD, and Git status before the user's terminal-only correction. This amendment updates the existing living plan; no new planning document is created.
- Init amendment baseline: `/tmp/terraform-init-baseline-gbd8dlcx`, containing the four existing scoped files, HEAD, and Git status. The untouched backend file was added to the snapshot before any backend edit. Temporary lookup tests created during this amendment were removed when the user rejected discovery; no new test file remains.
- Terraform `1.16.1` init help confirms repeatable initialization and that `-reconfigure` ignores saved backend configuration, while state migration is a separate option.

## Decisions

- 2026-09-30 commit amendment: The owner explicitly confirmed keeping both current `-auto-approve` flags and updating documentation/plans to match. This supersedes the interactive-approval decisions below. Lifecycle execution remains owner-run; the command flags are preserved, and no live execution is authorized. Review a speculative plan separately before invoking apply or destroy, accepting that execution uses a fresh proposal without a confirmation prompt.
- The user's request authorizes preparing local tasks, not executing Terraform lifecycle operations.
- Applied the repository planner and its global grill-with-docs, grilling, and domain-modeling dependencies. The decision tree is settled by the request and existing runbook: add the three named commands, retain existing paths and approval behavior, and keep execution owner-run. No material interview questions remain.
- Use direct mise tasks; no separate wrapper script or new configuration option is needed. The user's init request expands the command set to four tasks.
- The user's follow-up supersedes the original saved-plan choice: `plan` only displays its proposal; `apply` displays a fresh proposal and asks for approval. Both use `default.tfvars`, with no plan-file output or dependency. `destroy` is unchanged.
- The user explicitly authorizes adding reusable init with `-reconfigure`. Initialization was already repeatable; this flag reloads backend settings without migrating state. It does not eliminate the need to rerun init after changes or in another checkout.
- The user's latest steering rejects HeadBucket discovery: use one direct Terraform init command and put backend-specific values in `backend.s3.hcl`. The owner confirmed the bucket Region as `eu-west-1`; recorded it in the backend file. The platform Region remains `eu-north-1`. Live verification is owner-run preflight, not an agent action.
- Keep reusable AWS Region/default Region and account settings in mise env. The bucket and state key stay in the backend file; no duplicate state-bucket env setting or lookup helper remains. Do not guess a profile or duplicate Terraform's subnet and SSH inputs as environment variables. Keep credentials in the ignored file or existing credential chain.
- Scoped security findings: lifecycle tasks can mutate billable AWS resources and destroy diagnostic logs. Apply and destroy explicitly use owner-accepted `-auto-approve`; they have no confirmation prompt, and a prior speculative plan does not bind their execution. Descriptions and docs mark them owner-run, with separate plan review and no automatic task dependency. No credentials or permissions are changed.
- Init security findings: the existing credential chain and backend preflight remain required. Init writes local metadata and can download modules/providers but does not deploy, migrate state, or change AWS resources. No live init is authorized for agent validation. Backend bucket/key/locking remain unchanged; only an owner-confirmed Region may be added.

## Architecture impact

No topology, trust, resource ownership, connectivity, or reconciliation changes. These tasks wrap the existing Terraform procedure; an architecture diagram adds no information.

## Workstreams

### WS-1: Add and document lifecycle task entrypoints

**Delivers:** C1-C7 and A1-A3.
**Blocked by:** None.
**Seams:** mise task command expansion and the existing Terraform runbook.

- [x] Add reusable init/public env, record the owner-confirmed backend Region, update operator docs, dry-run entrypoints, run required checks/docs gate, and obtain independent review.

## Validation

- `mise run --dry-run plan`, `apply`, and `destroy` → C1-C3 and A1-A2 without executing Terraform.
- `mise run --dry-run init` → C5 task expansion without an AWS request or Terraform initialization.
- Owner-provided bucket Region and current backend file → C6.
- `mise exec -- terraform init -help` → C5 supported reconfigure/file flags without backend access.
- `mise exec -- terraform plan -help`, `apply -help`, and `destroy -help` → installed output and approval semantics for C1-C3.
- `mise run checks` → required local regression and security gates.
- `mise run docs-gate -- --plan docs/plans/2026-09-30-terraform-mise-tasks.md` → C4 documentation evidence structure.
- Snapshot comparison and direct independent review → C4 and A1-A3.

## Out of Scope

Executing live backend initialization or AWS discovery, actual cloud plan/apply/destroy, dependency installation, infrastructure changes, task names beyond init/plan/apply/destroy, commits, and publishing.

## Docs gate

- [x] Plan: evidence: docs/plans/2026-09-30-terraform-mise-tasks.md | Task criteria, safety boundaries, baseline, and validation evidence.
- [ ] Architecture: skip: The tasks preserve existing topology and lifecycle ownership.
- [x] Runbook: evidence: docs/runbooks/vpc-bastion.md | Owner-run reusable init, separate speculative plan review, automatic apply/destroy approval, fresh-plan risk, and teardown verification.
- [ ] ADR: skip: Direct wrappers are reversible and introduce no durable architectural trade-off.
- [ ] Glossary: skip: No domain term is introduced or redefined.
- [x] README: evidence: README.md | Public entrypoints for all four Terraform tasks.

## Progress

- 2026-09-30: Inspected local contracts and installed CLI versions; recorded task-start baseline before edits. Local implementation authorized; cloud execution excluded.
- 2026-09-30: All three mise dry-runs returned exit 0 and printed exactly the planned Terraform command, with no dependencies. Installed Terraform help confirms saved-plan apply skips its prompt and destroy aliases interactive apply with `-destroy`.
- 2026-09-30: `mise run checks` passed: 27 pytest tests, Terraform formatting and validation, TFLint, and Trivy configuration/secret scans. GitOps scan skipped because no GitOps YAML exists. Inspected checks and CI to confirm lifecycle tasks remain excluded.
- 2026-09-30: Compared the three edited files against the snapshot; changes contain only task additions and related operator documentation. The new plan is the only additional task artifact. The first docs-gate run rejected placeholder Outcomes text; replaced it with completed implementation evidence before rerunning.
- 2026-09-30: Docs gate passed. Independent reviewer returned `Decision: PASS` with no blockers or notes after independently checking dry-runs, CLI help, documentation, task isolation, baseline preservation, and plan ignore rules. This completion metadata was included in the review scope.
- 2026-09-30 amendment: The user requested terminal-only plan/apply without Terraform plan files. Prior saved-plan validation and PASS are historical and do not close this amendment. Recorded a new scoped baseline and updated the same living plan and operator docs. Amendment validation and independent review are open.
- 2026-09-30 amendment validation: All three dry-runs returned exit 0 and printed the expected commands. Local Terraform plan/apply help confirms terminal planning and interactive fresh-plan apply. Parsed TOML comparison against the amendment baseline confirms all settings and tasks except plan/apply are identical. Scoped diffs and Git status show only intended edits to the four existing scoped files, with no new documents. Required checks passed again with 27 pytest tests, Terraform formatting/validation, TFLint, and Trivy scans; GitOps scan skipped for absent YAML. Docs gate passed. No cloud lifecycle command ran. Independent review remains open.
- 2026-09-30 amendment review: Fresh independent review returned `Decision: PASS` with no blockers or notes. The reviewer independently verified the three command expansions, installed CLI semantics, docs gate, scoped baseline comparisons, task isolation, and preservation, and inspected captured required-check output. Routine completion metadata is covered by that assessment.
- 2026-09-30 init amendment: Added the authorized init task with automatic Region discovery and `-reconfigure`, preserving the three existing lifecycle commands. Recorded a scoped baseline. Three focused stub tests passed, covering repeated initialization in two Regions and failure before Terraform. Full validation and independent review are open; earlier PASS decisions are historical and do not close this amendment.
- 2026-09-30 init steering: Declared the known public AWS Region/default Region, account, and state bucket in mise env, and wired init to account/bucket variables. No credentials or private env values were read. Revalidation is required after this steering.
- 2026-09-30 final init steering: Removed lookup, its now-obsolete stub tests, and duplicate bucket env declaration. Init is a single command reading `backend.s3.hcl`; reusable AWS env settings remain in mise. Backend Region confirmation was requested. Earlier 30-test validation included the removed lookup tests and does not validate this final form.
- 2026-09-30 backend confirmation: The owner answered `eu-west-1`. Added only that Region to `backend.s3.hcl` and updated docs to distinguish it from the platform Region and preserve owner-run verification.
- 2026-09-30 final init validation: Dry-run printed exactly the one-line init command. Parsed TOML comparison confirms only the init task and three public AWS env declarations were added, with all existing task/settings unchanged. Backend snapshot comparison confirms only the owner-confirmed Region was added. Git status preserves pre-existing work and adds no new file. Required checks passed with 27 tests, Terraform formatting/validation, TFLint, and Trivy scans. No GitOps YAML exists, so its scan skipped. The docs gate rejected an unfinished marker in a historical progress entry; clarified that entry before rerunning. Independent review is open.
- 2026-09-30 init completion: Required checks and docs gate passed after the final edits; verbatim output is recorded in `/tmp/terraform-init-validation-output.txt`. Runtime assertions confirm mise passes the three public AWS env settings to child processes. Fresh independent review returned `Decision: PASS` with no blockers or notes, verifying all C1-C7 and A1-A3, the owner's backend Region answer, scoped snapshots, command expansions, docs, and runtime public env values. Routine completion metadata is covered by that assessment.

## Outcomes

Reusable initialization reads `backend.s3.hcl` with `-reconfigure` and owner-confirmed bucket Region `eu-west-1`. The owner confirmed retaining automatic apply/destroy approval; task descriptions, operator docs, and current criteria now match those flags. Public AWS settings remain in mise env, and no lookup helper or extra test file exists. Current checks, docs gates, dry-runs, preservation assertions, and independent review passed. No real backend initialization or AWS lookup ran; live access remains unverified and owner-run.

## 2026-09-30 commit amendment

Baseline `/tmp/feature-commit-baseline-gjr38qi7` records all non-ignored files, hashes, HEAD, and Git status before corrections. Snapshot/TOML assertions confirm all executable commands and public AWS/backend settings are preserved; only descriptions, operator docs, and plans are aligned with the confirmed flags and instance size. Previous PASS decisions remain historical.

Current validation in `/tmp/feature-commit-validation.txt` records 27 passing pytest tests, Terraform formatting/validation, TFLint, Trivy, both docs gates, four lifecycle dry-runs, Bash syntax, whitespace, and installed Terraform help. GitOps scanning skipped because no YAML exists. Independent review caught an active reference to interactive teardown; corrected it and reran the lifecycle docs gate and whitespace check. Targeted re-review returned `Decision: PASS` with no remaining blockers, covering all criteria/anti-criteria, the integrated feature, both commit boundaries, and routine completion metadata. Scoped security review found no additional blocker. No cloud operation, dependency installation, cost refresh, or publishing ran.
