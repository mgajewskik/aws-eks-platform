# AWS EKS Platform

An EKS platform built with Terraform for the AWS foundation and GitOps for cluster desired state. Changes follow repository-local planning, implementation, and independent review instructions, with tests and documentation maintained alongside the code.

## Status

The repository currently contains the development workflow, quality checks, and pytest tests for those checks. `platform/main.tf` is empty, and no cluster manifests are implemented. Passing these checks does not establish that a deployed platform is secure, highly available, or ready for workloads.

The target is one platform account in Stockholm, with optional connectivity to a transit gateway owned by a separate networking account. The deployed platform must support multi-AZ availability. Exact topology, GitOps and policy engines, bootstrap, and operational acceptance tests remain design work. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Run local checks

For initial local setup, prepare the pinned check tools and the locked Python environment:

```bash
rtk proxy touch .env.local
rtk proxy mise install python uv terraform tflint trivy
rtk proxy mise exec -- uv sync --locked --no-python-downloads
rtk proxy mise run checks
```

Mise loads `.env.local` for every task. Create the ignored file before setup; it may stay empty for checks. Setup writes local tool caches and `.venv/`; it does not access AWS. Required checks never install tools or Python packages. They can download Terraform providers/modules and Trivy policies when those inputs are needed. Optional AWS and Infracost tools are separate from CI setup.

All tests use Python and pytest. Manage Python dependencies in [pyproject.toml](pyproject.toml) with uv and commit [uv.lock](uv.lock). Run only the harness tests with:

```bash
rtk proxy mise run test-harness
```

Default collection is limited to `tests/harness/`. Live tests are a separate, explicitly selected workflow against a manually deployed platform. Tests never create or destroy the EKS platform. See [tests/README.md](tests/README.md).

## Work with agents

Read [the workflow guide](docs/dev/harness.md), then use the local [planner](.agents/skills/planner/SKILL.md), [implementer](.agents/skills/implementer/SKILL.md), and [reviewer](.agents/skills/reviewer/SKILL.md) skills. These are maintained copies of the owner's global `plan`, `implement`, and `review` skills, adapted for infrastructure work. Planning also requires the global `grill-with-docs`, `grilling`, and `domain-modeling` skills, which are intentionally not copied here.

Implementation includes documentation updates and independent review. Commit and publishing remain explicit user decisions. There is no publisher skill or deployment job.

## Checks and costs

The single GitHub Actions job runs the same `mise run checks` entrypoint as local development. It runs pytest, Terraform formatting and conditional validation/linting, plus Trivy configuration and secret scans. It has no AWS or Infracost credentials. See [AGENTS.md](AGENTS.md) for the required Feature-close documentation check.

Cost analysis is separate through `mise run cost`. It reuses the fingerprint in [docs/cost.md](docs/cost.md); refresh only when explicitly requested. The USD 100 monthly target must account for time deployed and retained resources after teardown. The current empty configuration is not a cost estimate for the intended HA platform.

Deployment is always an explicit operation on the owner's local machine. Deployment commands will be documented with the first implemented platform and its runbook.

## Repository map

| Path | Responsibility |
|---|---|
| [AGENTS.md](AGENTS.md), [.agents/skills/](.agents/skills/) | Workflow and local skills |
| [ARCHITECTURE.md](ARCHITECTURE.md), [CONTEXT.md](CONTEXT.md) | Ownership, target topology, and glossary |
| [platform/](platform/) | Terraform composition and modules |
| `gitops/` | Future cluster desired state |
| [tests/](tests/README.md) | Pytest suites and test boundaries |
| [docs/plans/](docs/plans/), [docs/adr/](docs/adr/) | Living plans and architecture decisions |
| [docs/runbooks/](docs/runbooks/), [docs/research/](docs/research/) | Operator procedures and cited research |
| [.mise.toml](.mise.toml), [pyproject.toml](pyproject.toml), [uv.lock](uv.lock) | Pinned tools and Python dependency lock |

The first platform feature needs a priced multi-AZ topology, explicit bootstrap ownership, and observable security and workload acceptance criteria before implementation.
