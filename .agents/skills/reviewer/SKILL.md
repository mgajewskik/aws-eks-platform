---
name: reviewer
description: Review infrastructure changes since a Git ref or explicit file baseline against the plan and repository standards. Use for an explicitly requested branch, PR, or fixed-point review, including staged, unstaged, and new files.
---

# Reviewer

Review two separate axes:

- **Standards**: documented repository rules, infrastructure safety, and maintainability.
- **Spec**: the originating plan's criteria, anti-criteria, and intended architecture.

For an explicitly requested fixed-point review, run these axes in parallel fresh contexts with review-only assignments, then aggregate their findings. Automatic implementation completion instead uses the single dedicated reviewer defined in `AGENTS.md`; do not recursively load this workflow.

## 1. Establish the baseline and scope

Use the Git ref the user supplied. If none was supplied, ask for the baseline. Resolve the ref, record its merge base with HEAD, and inspect committed, staged, and unstaged changes against that base. Enumerate scoped untracked files separately because `git diff` omits them.

For an unborn repository, use an explicit task-start file snapshot or an empty-tree baseline for an initial-import review. State which files predate the task. Stop if the requested baseline cannot be established or there are no task changes. Prefix interactive shell commands with `rtk`.

## 2. Find the plan and standards

Find the originating plan from the user, branch/commit references, or the actual plans directory. If no spec can be found, ask for it and report the Spec axis as unavailable until resolved.

Read `AGENTS.md`, the applicable architecture and ADRs, operational runbooks, tests, and check configuration. Prefer the current files and installed tool versions over assumptions. List the standards sources used. Check the plan's architecture diagram against the configuration and ownership rules when the change affects architecture.

Required checks are the commands in `AGENTS.md`. Use recorded current evidence or run them when permitted. Do not run deployment, live scenarios, dependency installation, or cost analysis as incidental review actions. A required behavior with no evidence stays unverified.

## 3. Apply the infrastructure review lens

Use these as evidence-guided questions, not an unconditional checklist of changes to demand:

| Area | Concrete failures to look for |
|---|---|
| Resource identity and state | Address changes that replace resources unintentionally, mixed environment state, missing migration/retention decisions, unreviewed destructive effects |
| Ownership and reconciliation | Terraform and a controller managing the same resource, ambiguous GitOps bootstrap, conflicting reconcilers, deletion order that leaves resources behind |
| Identity and secrets | Excess IAM or Kubernetes permissions, untrusted CI credentials, secret values in configuration/state reports, missing workload identity boundaries |
| Networking | Unintended exposure, missing return routes, overlapping CIDRs, incorrect account/TGW ownership, DNS or local-runner access assumptions |
| Workload and data safety | Availability claims unsupported by placement/capacity, ineffective policy fixtures, volume reclaim/data-loss risks, unbounded cleanup or retention |
| Versions and operations | Unsupported tool/provider/add-on combinations, mutable deployment dependencies, absent recovery/upgrade evidence, drift between code and runbooks |
| Cost and scope | Unaccounted billable or retained resources, cached estimates used outside their stated assumptions, changes beyond the plan; cost execution stays opt-in |
| Simplicity | Unnecessary modules, copied environment trees, misleading names, speculative multi-account machinery, or repeated configuration that makes a real change error-prone |

Repository rules override generic preferences. Treat a smell as a judgment unless the evidence demonstrates a requirement violation or concrete failure. Do not duplicate findings already enforced by passing tooling.

There is no application architecture, OOP, inheritance, method-chain, or mandatory typechecking baseline for Terraform/YAML. Those programming rules do not belong in an infrastructure review.

### When Python tests or tooling change

Review only the changed Python behavior for readable names, misleading assertions, unnecessary duplication/abstractions, subprocess targeting, and sensitive output. Check that pytest cases assert observable behavior, failures propagate, fixtures stay local unless explicitly selected as live, and cleanup targets only resources created by the case.

Use the same pytest/uv rules as the repository. Require a regression test when it is needed to establish a bug fix; do not impose a test-first cloud deployment or invent a type checker.

## 4. Run independent reviews

Use the runtime's supported mechanism for two fresh independent reviewers, one per axis. Normal runtime permissions, including write access, are acceptable; this repository does not require a read-only sandbox. Each assignment is review-only: inspect the change, run permitted checks, and report findings. Neither reviewer edits reviewed files, implements fixes, or delegates. Permitted checks may produce temporary test artifacts and caches. If independent review cannot be established, report blocked; write permissions alone are not a blocker.

Give both reviewers the exact baseline, complete scoped file list including untracked files, plan, standards sources, direct impact paths, and validation evidence.

- Standards reviewer: report documented-rule violations and applicable infrastructure risks. For each blocker, name the location, rule or failure scenario, and consequence. Label non-blocking judgment separately.
- Spec reviewer: check every criterion and anti-criterion against current files and behavior. Report missing, partial, extra, or incorrectly implemented requirements, quoting the plan.

Missing evidence blocks only when it prevents establishing a required behavior or safety property. Name the missing check. Taste and unrelated pre-existing issues are non-blocking.

## 5. Report and close

Present Standards and Spec separately, then report `Decision: PASS`, `Decision: FAIL`, or `Decision: BLOCKED`. PASS requires green required checks, evidence for all criteria and anti-criteria, and no blockers on either axis. Never turn unavailable evidence into PASS.

Fixes belong to implementation. After confirmed blockers are addressed and locally checked, request targeted re-review of the affected paths. Preserve earlier evidence for unaffected criteria; use a fresh full review only for materially changed scope.
