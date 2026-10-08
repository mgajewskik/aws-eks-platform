# AWS EKS Platform

Terraform owns the AWS foundation. GitOps owns cluster desired state. Agents plan, implement, verify, review, and update documentation with each change. The owner applies from a local machine.

Read [docs/dev/harness.md](docs/dev/harness.md) before changing the workflow. Repository-local skills in `.agents/skills/` (linked from `.claude/skills/`) are the authoritative copies for this project.

## Workflow

1. Plan with [planner](.agents/skills/planner/SKILL.md): one living plan per change in `docs/plans/`, with criteria tagged by verification tier, anti-criteria, and workstreams that a subagent can take alone. When a decision is open, interview with the global `grill-with-docs` skill and its global `grilling` and `domain-modeling` dependencies; do not vendor them. Ask only about material unresolved decisions.
2. Implement the plan. Before editing Terraform, write the expected replacements and deletions into the plan. Reproduce bugs as failing tests before fixing them. Record each finished step in Progress, with how it was done and its evidence, so another session can resume from the file.
3. Update affected documentation in the same change as the code (see Documentation). A change is not complete while any doc it affects is stale.
4. Verify each criterion at its tier. Then obtain review from a fresh-context reviewer that checks Spec and Standards against the plan and these rules, without loading another review workflow or delegating. Give it the task-start baseline, all scoped staged, unstaged, and new files, and the verification evidence. The reviewer inspects and reports; it does not edit reviewed files.
5. Fix evidence-backed blockers and request targeted re-review. If independent review is unavailable, report blocked. Purely informational requests need no review.
6. At feature close, follow the [cost-audit](.agents/skills/cost-audit/SKILL.md) skill once: a major billable change runs `mise run cost`, and any other change only records the new fingerprint. Set the plan Status.
7. Report changes as ready. Commit, push, or open a PR only on explicit request, using the installed global `commit` skill. When a plan covers the change, end the message with a `Plan: docs/plans/<file>.md` trailer. Pre-commit runs the fast checks; re-run them if reviewed files change.

## Verification tiers

| Tier | Proves | Command | Credentials |
|---|---|---|---|
| static | Code, tests, and IaC scans pass | `mise run checks` (CI); pre-commit runs a fast subset | none |
| plan | The change does what the plan says and passes the plan policy | `mise run plan` | read-only |
| live | The deployment matches the code and works as designed | `mise run verify-live` after apply | read-only |

Plan Status: `draft` → `ready` → `in progress` → `done` → `verified`. `done` means static and plan criteria pass, review returned `Decision: PASS`, and `scripts/cost.sh --check` passes. `verified` means live criteria passed after the owner's apply. A green tier proves only that tier.

`mise run plan` saves `platform/tfplan` only when [the plan policy](scripts/plan_policy.py) passes, and `mise run apply` applies exactly that file. Each plan replaces the saved one, so the owner plans immediately before applying; agents never pass `-destroy` or `-replace`. Tear down with `mise run plan -- -destroy`, then `mise run apply`. When a new resource type needs an invariant, add it to the policy with a test in the same change.

For an explicitly requested branch or fixed-point review, use [reviewer](.agents/skills/reviewer/SKILL.md).

## Safety and ownership

- AWS and cluster changes happen only through Terraform in `platform/` and manifests in `gitops/`. Never change resources through the console, AWS CLI, or `kubectl`, and change state only with `import`, `moved`, or `removed` blocks.
- Apply is owner-run from the owner's machine. Agents never run `mise run apply`, `terraform apply` or `destroy`, cluster or AWS mutations, data writes, or destructive cleanup. Tests never deploy or destroy the platform. The path to autonomous apply is in [docs/dev/harness.md](docs/dev/harness.md).
- With the owner's credentials loaded, agents may run read-only live commands: AWS `describe`/`get`/`list` calls, `kubectl get`/`describe`/`logs`, `terraform output`/`state list`/`state show`, `mise run plan` without extra arguments (a transient S3 state lock and a local plan file), and `mise run verify-live`. In Claude Code sessions only the sandbox-excluded `mise` tasks reach AWS ([docs/dev/harness.md](docs/dev/harness.md)). Verify account, Region, and cluster context first. Never read secret values (Secrets Manager values, Kubernetes Secret data, credentials, sensitive Terraform outputs via `-json` or `-raw`), print sensitive environment values, or print, copy, or commit plan files, which hold sensitive values in plain text.
- Required checks need no AWS or Infracost credentials and never call their APIs. Mise loads `.env.local` for every task; do not print its values. CI uses an empty environment file. Terraform init may download providers; Trivy may update policies.
- Terraform lives under `platform/`, GitOps YAML under `gitops/`. Each resource has one lifecycle owner; Terraform never also manages a controller-owned resource such as a load balancer or volume. Terraform state cannot see controller-owned resources, so the change that adds the first controller provisioning AWS resources (load balancer controller, EBS CSI, external-dns, Karpenter) also adds a destroy step that deletes those Kubernetes objects before the cluster, and a read-only live check that nothing tagged for this cluster remains afterwards. Query by the cluster tag only, never the whole account.
- Secret values stay out of Git, tfvars, logs, and reports. Store runtime secrets in AWS Secrets Manager and reference ARNs.
- S3 bucket names include a unique prefix and entropy.
- Infracost's free tier limits runs per month. Run `mise run cost` only at feature close; it reuses its cache. Refresh only on explicit request. Never add Infracost to checks, tests, pre-commit, or CI. Estimates live in `docs/cost.md`.
- Review changes to `platform/`, `gitops/`, `.github/`, checks, and agent safety rules for privilege, credentials, exposure, and destructive effects. Record the findings, or `none`, in the living plan.
- Preserve pre-existing work in the working tree.

## Code and tests

Write code and tests the way an experienced engineer writes them by hand: no more code than the intent needs. When shorter and clearer conflict, choose clearer; do not compress to save lines.

- No checks for states that cannot occur, no branches for cases that no longer exist, and no messages that repeat an error the tool already prints.
- Comments explain why, never what the next line does.
- One test per behavior; use a parametrized table for input variations instead of a test per case.
- When a change makes code unused, delete it in the same change.

## Tests

All tests are pytest; manage Python packages with uv in `pyproject.toml` and commit `uv.lock`. Do not add unittest, Terratest, or native Terraform tests. Default collection is `tests/harness/`. Live suites in `tests/live/` are read-only, run only through their mise tasks, verify account and Region first, and never manage the platform lifecycle. Tests that create or change live resources are out of scope. See [tests/README.md](tests/README.md).

```bash
mise run checks          # static tier, locally and in CI
mise run test-harness    # harness pytest only
pre-commit install       # once per clone: fast checks before every commit
```

`uv sync --locked` prepares the environment when installation is authorized. Checks run `uv run --locked --no-sync --no-env-file pytest`. A green check is not evidence of deployed security or availability.

## Documentation

Update docs in the same change as the code they describe:

| Change | Update |
|---|---|
| Usage, setup, or status | README |
| Topology or ownership | ARCHITECTURE |
| Operator procedure | Runbook |
| Durable decision with real alternatives | ADR |
| Settled term | CONTEXT |
| Billable resource | `docs/cost.md` via the cost-audit skill |

Keep docs minimal and durable so they rarely go stale:

- Describe design, ownership, and procedure, not deployment values. Account IDs, domains, address allocations, instance types, and versions live in tfvars, backend files, or GitOps overlays, and docs point to them. Use `example.com` for domains.
- Status wording matches the repository: implemented, designed, or not started. Never imply deployed resources.
- State each caveat once, where it applies. Prefer a table, list, or diagram over paragraphs.
- Do not reference interview rounds, chat history, or personal tooling.
- Do not commit files that add no lasting value. `docs/research/` is local scratch and gitignored.

Record the docs a change updated, or why none needed it, in the plan's Outcomes. The reviewer checks that claim against the diff.

## Map

- [docs/dev/harness.md](docs/dev/harness.md): workflow and skill provenance.
- `docs/plans/YYYY-MM-DD-<kebab-slug>.md`: living plans; [template](docs/plans/TEMPLATE.md).
- `docs/adr/NNNN-<kebab-slug>.md`: next unused number after the [template](docs/adr/0000-template.md).
- `docs/runbooks/<kebab-procedure>.md`: operator procedures; [template](docs/runbooks/TEMPLATE.md).
- [CONTEXT.md](CONTEXT.md): glossary. [ARCHITECTURE.md](ARCHITECTURE.md): design and ownership. [docs/cost.md](docs/cost.md): estimates.
- [cost-audit](.agents/skills/cost-audit/SKILL.md): cached estimates and requested billing analysis.
- `scripts/plan_policy.py`: plan invariants. `tests/live/`: read-only live suite.

Use pinned tools through mise. Do not install dependencies or change external systems without explicit authorization.
