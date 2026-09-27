# AWS EKS Platform

Terraform owns the AWS platform foundation. GitOps owns cluster desired state. Agents plan, implement, test, review, and update documentation with each change. The owner runs deployment from a local machine.

Read [docs/dev/harness.md](docs/dev/harness.md) before changing the workflow. Repository-local skills are the authoritative copies for this project.

## Workflow

1. Use [planner](.agents/skills/planner/SKILL.md) for a living plan with binary criteria, anti-criteria, and validation. Use existing authorization; ask only about material unresolved decisions.
   Planning always uses the installed global `grill-with-docs` skill and its global `grilling` and `domain-modeling` dependencies. Do not vendor those supporting skills. Include an architecture diagram in the plan when an architecture change can be clarified visually.
2. Use [implementer](.agents/skills/implementer/SKILL.md) to execute the plan. Reproduce bugs before fixing them and update affected docs with the code.
3. Run the required checks. For implementation changes, obtain independent review in fresh context. The dedicated reviewer checks Spec and Standards directly against the plan and repository rules, without loading another review workflow or delegating. Give it the task-start baseline, all scoped staged/unstaged/new files, and validation evidence. Do not rely on a committed-only diff. The reviewer has a review-only assignment: inspect, run permitted checks, and report findings; do not edit reviewed files or implement fixes. Normal runtime permissions, including write access, are acceptable. This repository does not require a read-only sandbox. Fixes belong to the implementer.
4. Fix evidence-backed blockers and request targeted re-review. Completion requires all criteria and anti-criteria verified, required checks green, and `Decision: PASS`. If independent review is unavailable, report blocked. Purely informational requests require no completion review.
5. Report changes as ready. Commit, push, or create a PR only on an explicit user request. Use the installed global `commit` skill for every commit-message or commit operation. Use Conventional Commits with the skill's required `Why:` and `What:` sections. Re-run checks if the reviewed files change. There is no publisher role.

For an explicitly requested branch or fixed-point review, use [reviewer](.agents/skills/reviewer/SKILL.md). It retains separate Spec and Standards reports. Automatic completion review uses the dedicated reviewer above, avoiding a nested review pipeline.

## Safety and ownership

- Deploy only from the owner's local machine. Agents never run `terraform apply` or `destroy`, cluster mutations, or destructive cleanup. Tests never deploy or destroy the platform. Explicitly selected live workload scenarios are user-run, scoped, and include cleanup verification.
- Required checks need no AWS or Infracost credentials and never call their APIs. Mise loads `.env.local` for every local task, so processes may inherit those variables; do not print them. CI uses an empty environment file and receives no cloud credentials. Terraform initialization may download providers/modules; Trivy may update policies. These checks do not modify cloud resources.
- Keep Terraform under `platform/` and GitOps YAML under `gitops/`. Kubernetes controllers can provision dependent AWS resources such as load balancers and volumes. Each resource has one lifecycle owner; Terraform must not also manage a controller-owned resource.
- Secret values stay out of Git, tfvars, logs, and test reports. Store runtime secrets in AWS Secrets Manager and reference ARNs. Commit non-secret environment parameters and `.mise.toml`. Local `.env.local`, Terraform state, and agent logs remain ignored.
- S3 bucket names include a unique prefix and entropy.
- Cost analysis is separate and opt-in through `mise run cost`. Reuse its cache and run `refresh` only on an explicit request. Never add cost estimation to required checks, tests, pre-commit, or CI. Budget assumptions and estimates live in `docs/cost.md`.
- Review changes to `platform/`, `gitops/`, `.github/`, checks, and agent safety rules for privilege, credentials, exposure, and destructive effects. Record the scoped security findings or `none` in the living plan. This review is required even when optional external audit skills are unavailable.
- Preserve pre-existing work. For an unborn repository, record a file snapshot before editing; include new files in review. Do not fabricate a Git baseline.

## Tests and Python dependencies

All tests are Python tests run by pytest. Manage every Python package through uv in `pyproject.toml` and commit `uv.lock`. Add test dependencies to the development group. Do not introduce unittest, Go/Terratest, or a separate native Terraform test suite. Pytest may invoke CLI validators when that is the behavior under test.

The default pytest collection is `tests/harness/`. Future live suites must live outside that default path, require explicit selection, verify account/region/cluster identity, and keep platform lifecycle out of fixtures. A local test fixture may mutate temporary files; a live scenario that creates workloads remains user-run.

Use `uv sync --locked` to prepare the environment when dependency installation is authorized. Required checks use `uv run --locked --no-sync --no-env-file pytest`, so uv does not install packages or load an additional dotenv file. The process still inherits the environment loaded by mise. CI prepares the locked environment in a separate setup step.

## Feedback loops

Required local and CI command:

```bash
rtk proxy mise run checks
```

It runs pytest harness tests, Terraform formatting, conditional validation and TFLint, and Trivy misconfiguration and secret scans. Empty Terraform/GitOps checks report skips. A green result is not evidence of deployed security or HA.

Focused harness tests:

```bash
rtk proxy mise run test-harness
```

Feature close additionally requires:

```bash
rtk proxy mise run docs-gate -- --plan docs/plans/YYYY-MM-DD-<kebab-slug>.md
```

Keep cost estimation, Terraform plans, and live tests outside these commands. They need explicit selection and the appropriate local credentials. Read [tests/README.md](tests/README.md) before designing a live test. Publishing and deployment are separate decisions.

## Documentation

Update README when usage changes, ARCHITECTURE when topology or ownership changes, and runbooks when operator procedures change. Record a glossary term when its meaning is settled. Use an ADR for a durable decision with real alternatives. Do not create documents solely to tick a box.

Fill the plan's Docs gate using the [docs-gate skill](.agents/skills/docs-gate/SKILL.md). Its command checks evidence structure and file existence. The independent reviewer checks whether the evidence and skip reasons are accurate. Agents update docs as part of implementation; CI checks them but does not author prose or run an AI reviewer.

## Map and skills

- [docs/dev/harness.md](docs/dev/harness.md): workflow, local skill provenance, and manual publishing boundary.
- [planner](.agents/skills/planner/SKILL.md), [implementer](.agents/skills/implementer/SKILL.md), [reviewer](.agents/skills/reviewer/SKILL.md): locally maintained copies of the owner's workflow skills.
- Global prerequisites: `grill-with-docs`, `grilling`, and `domain-modeling`. Planning requires them; their files remain outside this repository.
- [docs-gate](.agents/skills/docs-gate/SKILL.md): documentation evidence at Feature close. [cost-audit](.agents/skills/cost-audit/SKILL.md): separate cached estimates and explicitly requested billing analysis.
- `docs/plans/YYYY-MM-DD-<kebab-slug>.md`: living plans; [template](docs/plans/TEMPLATE.md).
- `docs/adr/NNNN-<kebab-slug>.md`: decisions in creation order; next unused number, starting at `0001`, excluding [0000-template.md](docs/adr/0000-template.md).
- `docs/runbooks/<kebab-procedure>.md`: operator procedures; [TEMPLATE.md](docs/runbooks/TEMPLATE.md).
- `docs/research/YYYY-MM-DD-<kebab-slug>.md`: cited research.
- [CONTEXT.md](CONTEXT.md): glossary. [ARCHITECTURE.md](ARCHITECTURE.md): ownership and topology. [docs/cost.md](docs/cost.md): cached estimates and budget assumptions.
- `platform/`: Terraform foundation. `gitops/`: desired cluster state. [tests/](tests/README.md): harness checks and the platform test contract.

## Shell

Prefix interactive shell tool calls with `rtk`; use `rtk proxy` when passthrough is needed. Repository scripts and CI call their underlying tools directly and do not require RTK on the runner. Use pinned tools through mise. Do not install dependencies or change external systems without explicit authorization.
