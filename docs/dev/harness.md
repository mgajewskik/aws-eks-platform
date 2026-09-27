# How to use this harness

Read [AGENTS.md](../../AGENTS.md) for the authoritative workflow, safety rules, and check commands. This guide explains how the repository-local skills fit together.

## Plan and implement a change

1. Use [planner](../../.agents/skills/planner/SKILL.md) to create a living file under `docs/plans/`. Its mandatory global `grill-with-docs` interview resolves design decisions and terms. Use the [plan template](../plans/TEMPLATE.md), name binary criteria and anti-criteria, and diagram architecture changes when a diagram clarifies them.
2. Use [implementer](../../.agents/skills/implementer/SKILL.md) to execute authorized work. Reproduce bugs, run focused pytest cases, and update affected documentation with the code.
3. Run `rtk proxy mise run checks`. At Feature close, fill the documentation evidence and run `rtk proxy mise run docs-gate -- --plan <plan-path>`.
4. Give a fresh independent reviewer the plan, task-start baseline, all changed/new files, and validation evidence. Its assignment is review-only: inspect, run permitted checks, and report findings. Normal write permissions are acceptable, but the reviewer leaves repository edits and fixes to the implementer. Fix blockers and obtain `Decision: PASS`.
5. Review the ready changes and decide when to commit or publish. Use the installed global `commit` skill and Conventional Commits with `Why:` and `What:` sections for commit messages. A completed implementation does not authorize a commit, push, or deployment.

When a user asks only for planning, stop at the plan. Existing implementation authorization does not need another permission question unless a material decision or risk changes.

The [reviewer skill](../../.agents/skills/reviewer/SKILL.md) handles explicit reviews since a Git ref or file snapshot. It retains separate Spec and Standards reports. Automatic completion review uses one dedicated independent reviewer, so it does not recursively start another review workflow. If the runtime cannot provide independent review, report blocked. The repository does not require read-only filesystem permissions; stricter session-level restrictions may still apply.

## Local skill copies

The `planner`, `implementer`, and `reviewer` directories contain real procedures, not wrappers around skills installed elsewhere. They were copied from the owner's global skill collection on 2026-09-27 and are maintained in this repository. There is no automatic synchronization.

| Skill | Repository adaptation |
|---|---|
| `planner` from global `plan` | Requires the global grill-with-docs interview, uses the repository template, includes applicable architecture diagrams, and respects existing scope authorization. |
| `implementer` from global `implement` | Uses infrastructure configuration and policy checks plus explicitly selected live evidence. Pytest regression checks apply to testable Python/tooling changes, without blanket TDD or typechecking. |
| `reviewer` from global `review` | Keeps Spec and Standards, with infrastructure risks as its baseline and Python concerns only for changed tests/tooling. Includes all scoped working-tree files and uses independent reviewers with review-only assignments. |

Original source SHA-256 values provide a comparison baseline without requiring access to the original machine:

```text
plan       3ffe6bcb0fb69e1fcd2583d55bf4f77ebae35504f570461b703fb92fc797aeb1
implement  9bfd4e9b08a0573316daf56e5912de1468365cd90ac38b4610c14ed0aecd8c93
review     f29ec6093ee518b3e02b5587f0d4180e951755f21a5eacecc4299f7d95c8c01e
```

The local [docs-gate](../../.agents/skills/docs-gate/SKILL.md) and [cost-audit](../../.agents/skills/cost-audit/SKILL.md) skills remain repository-specific.

The planning interview deliberately depends on the installed global `grill-with-docs`, `grilling`, and `domain-modeling` skills. They are not copied into this repository. Planning stops with a named dependency error if they are unavailable. Use the repository ADR template when an interview produces an ADR. Global skill files remain unchanged.

A publisher skill is unnecessary while publication means the owner reviews the diff and deliberately commits or pushes. Add a publishing procedure only when repeated release work creates a concrete need.

## Maintain documentation with code

Use the Docs gate section on every Feature plan. It names the plan, architecture, runbook, ADR, glossary, and README. Each item needs file evidence and an explanation, or a specific skip reason when that document did not need to change. The plan cannot be skipped.

The command checks structure and file existence. It cannot decide whether prose is correct or whether a skip was justified. That is part of independent review. CI runs regression tests for the checker; the Feature-close command is separate from ordinary checks.

See [ADR-0002](../adr/0002-docs-gate-is-a-feature-command.md) for that boundary. Agents author updates during implementation; CI does not generate or publish prose.

## Keep setup, checks, cost, and deployment separate

- Prepare tools and Python dependencies explicitly. All Python packages use uv with `pyproject.toml` and `uv.lock`; all tests use pytest.
- `mise run checks` and `mise run test-harness` use the prepared environment. Mise task auto-install is disabled, and pytest runs with uv's `--no-sync`.
- Mise loads `.env.local` for every local task, as selected by the owner. Processes inherit those variables, but required checks need no cloud credentials and must not print them. CI creates an empty `.env.local` and receives no cloud credentials.
- `mise run cost` is explicitly selected and cached. Required checks, pre-commit, and CI never call it.
- Live tests require explicit selection and target verification. The owner runs mutating scenarios. See [tests/README.md](../../tests/README.md).
- The owner deploys from a local machine. CI only checks repository changes. See [ADR-0003](../adr/0003-ci-checks-apply-is-local.md).

Before the first commit, treat all existing files as pre-existing work. Record their baseline and review the task's changes without assuming HEAD exists. Keep `.mise.toml` eligible for Git and exclude local credentials, state, virtual environments, and agent logs.
