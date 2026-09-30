# AWS EKS Platform

An EKS platform built with Terraform for the AWS foundation and GitOps for cluster desired state. Changes follow repository-local planning, implementation, and independent review instructions, with tests and documentation maintained alongside the code.

## Status

The repository contains a Terraform VPC and private SSM bastion in `platform/`, plus local connection tasks and checks. No infrastructure has been deployed and no cluster manifests are implemented. Passing local checks does not establish live connectivity, security, or availability.

The current foundation targets account `220263133738` in Stockholm (`eu-north-1`): three public and three private subnets, regional NAT, and one private AL2023 `t4g.medium` bastion. EKS, GitOps, and optional transit-gateway connectivity remain future work. See [ARCHITECTURE.md](ARCHITECTURE.md).

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

Cost analysis is separate through `mise run cost`. It reuses the fingerprint in [docs/cost.md](docs/cost.md); refresh only when explicitly requested. The cached VPC/bastion estimate does not cover EKS, usage, or a complete HA platform. The USD 100 monthly target must account for time deployed and retained resources after teardown.

Deployment and the SSM/SSH/sshuttle tunnel are owner-run. Follow the [VPC and bastion runbook](docs/runbooks/vpc-bastion.md) for backend preflight, plan/apply, connectivity, and teardown. `mise run bastion`, `mise run ssh`, and `mise run vpn` require `session-manager-plugin` on `PATH` and use the deployed Terraform connection output. The plugin is managed outside this repository. `sshuttle` is a normal locked uv dependency. The current foundation's cached cost scenarios are in [docs/cost.md](docs/cost.md).

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

EKS implementation and its live acceptance checks remain future work.
