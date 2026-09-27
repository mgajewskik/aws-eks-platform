---
name: implementer
description: Implement an authorized infrastructure plan using configuration checks, pytest where applicable, documentation updates, and independent review.
---

# Implementer

Implement the authorized work from the living plan under `docs/plans/`. Read `AGENTS.md` and the plan's criteria, anti-criteria, and validation before editing. Record a task-start baseline including existing staged, unstaged, and untracked files.

## Implement infrastructure

1. Inspect the affected Terraform modules, manifests, policy, tool pins, callers, and ownership rules. Check the plan's architecture diagram against the intended change. Identify replacements, resource deletions, cross-account effects, permissions, and retained resources before editing. Completion: the intended impact and local versus live validation are explicit.
2. Make the smallest configuration change that meets the plan. Use pinned tool/provider behavior and preserve existing resource identities. Keep Terraform-owned and controller-owned resources separate. Completion: each changed path maps to a criterion or necessary evidence.
3. Run the applicable local checks: Terraform format/validate/lint, YAML rendering or schema validation when present, policy checks, and security scans. Repeat the affected check after a fix. Infrastructure changes do not require a programming type checker or a test-first deployment. Completion: local checks pass, with unsupported or unavailable checks named.
4. For behavior that can only be established on deployed resources, define a separate pytest case or user-run procedure against an existing platform. Require explicit target selection and cleanup verification for temporary workload scenarios. Agents do not deploy the platform to obtain a green test. Completion: live evidence is either supplied or reported as unverified. A required live criterion keeps the platform feature incomplete until the owner supplies it.

## Python tests and tooling

All tests use pytest and all Python packages use uv with `pyproject.toml` and `uv.lock`. When changing a Python test helper or executable script, reproduce an observable bug with a failing pytest case when practical, then verify the fix with that case. This applies to testable tooling behavior, not to deploying EKS as a test fixture. Run focused tests during the change and the full required check entrypoint before handoff. Do not invent a typechecking gate when none exists in this repository.

## Documentation and review

Update affected documentation with the code and fill the plan's documentation evidence. Run the required checks and Feature-close docs gate named in `AGENTS.md`. Cost estimation and live tests are separate opt-in operations.

Hand the integrated result, plan, baseline, changed paths, and validation evidence to the independent reviewer required by `AGENTS.md`. The reviewer checks Spec and Standards directly in fresh context with a review-only assignment. It may have normal write permissions, but leaves edits and fixes to the implementer. Fix confirmed blockers and request targeted re-review until `Decision: PASS`. Use the local `reviewer` skill for an explicitly requested review since a Git ref. If independent review cannot run, report blocked rather than approving your own work.

Report the changes as ready when checks and required review pass. Commit only when the user explicitly asks. Publishing also requires a separate explicit request; there is no publisher skill.
