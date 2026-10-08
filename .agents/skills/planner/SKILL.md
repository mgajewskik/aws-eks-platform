---
name: planner
description: Plan work as a living markdown file with binary success criteria, anti-criteria, and independent workstreams. Use when planning a feature or change, including when the conversation already contains the design.
---

# Planner

Create one **living plan file** for new work and keep it current as the picture sharpens. The file is both the implementation contract and the decision record, and it lands on disk early so a lost context never loses the plan. It scales from a single small feature to multi-lane work.

This skill produces the plan file. Read the repository's `AGENTS.md` for the workflow and use the [repository plan template](../../../docs/plans/TEMPLATE.md). A planning-only request stops at the plan. An existing request to implement may authorize the next stage once material decisions are settled.

## Process

### 1. Frame

Recover everything the invocation already states — goal, constraints, non-goals. Nothing recovered here gets re-asked later.

### 2. Explore

Answer code-answerable questions from the codebase, not from the user. Collect the paths, symbols, and docs the plan will cite — only what was actually inspected. Done when every remaining question is genuinely user-only.

### 3. Write the skeleton immediately

As soon as the goal can be named, put the file on disk — before any interview. Resolve the location in order:

1. explicit path from the user
2. a plans-location instruction or convention already in the repo
3. an existing `./plans` or `./docs/dev/plans`, when exactly one exists
4. `./plans`

Name it `YYYY-MM-DD-<kebab-slug>.md`, fill the repository template with what framing and exploration already settled, set `Status: draft`. Done when the file exists on disk.

### 4. Interview when a decision is open

When a decision that would change the goal, criteria, or workstreams is still open, load and use the installed global `grill-with-docs` skill. Its global `grilling` and `domain-modeling` dependencies remain global. Do not copy these supporting skills into this repository. If a required global skill is unavailable, stop and report the missing dependency instead of guessing the decision.

Recover decisions already answered before asking anything. Record answers in this plan, and update resolved terms or qualifying ADRs. A settled scope needs no interview; record that and the existing authorization. Either way, the plan establishes:

- What does done look like, observably? → feeds success criteria
- What must never happen? → feeds anti-criteria — every non-trivial plan needs at least one

Done when no open decision would still change the goal, criteria, or workstreams — or the user defers one, which keeps `Status: draft` with the blocker named.

### 5. Show architecture changes

Assess whether the plan changes topology, account or trust boundaries, resource ownership, connectivity, or reconciliation/data flow. If the change can be usefully shown, include a Mermaid diagram in the plan's Decisions. Label current and proposed behavior, show affected boundaries and ownership, and avoid implying that proposed resources already exist. A before/after pair is useful when a single diagram hides the change.

Check that the diagram agrees with the written decisions and inspect a rendered diagram when a renderer is available. Record unavailable rendering rather than claiming it passed. If no architecture changes or a diagram cannot clarify the change, say so in one line. Update `ARCHITECTURE.md` with the implementation, not as a substitute for the plan's diagram.

### 6. Define done

Map every requirement and hard constraint to a **binary** success criterion with a concrete verification method: a command with a pass/fail signal, an observable state, or a measured threshold with units. Tag each criterion with the verification tier from `AGENTS.md` that proves it (`static`, `plan`, or `live`); prefer the earliest tier that can prove it, and add a `live` criterion only for behavior earlier tiers cannot see. When a change adds a resource type, add a criterion for its plan-policy invariants. Anti-criteria name the likely regressions, scope leaks, and forbidden shortcuts, verified by non-occurrence. Replace "works correctly"-style vagueness with observable outcomes. A criterion without a verification method keeps the plan in `draft`.

### 7. Shape the workstreams

Break the work into tracer-bullet workstreams:

- vertical slices, each independently verifiable and sized to fit one fresh context
- blocking edges declared — a workstream with no blockers can start immediately; prefactoring goes first
- small work is exactly one workstream
- every workstream maps to at least one criterion, every criterion to at least one workstream

Independent workstreams let parallel subagents each take one in a fresh context; the Progress section lets a later session resume where work stopped.

### 8. Confirm

Present the goal, criteria, workstreams, and validation commands. Use explicit authorization already given for this scope, or ask when a material decision remains. Record the authorization in Decisions and set `Status: ready`. For a planning-only request, stop here.

## Living file

The plan file is the single source of truth for the work: update it whenever new information lands or the plan changes shape. Status flow and its meaning are defined in `AGENTS.md`: `draft` → `ready` → `in progress` → `done` → `verified`.

## Template

Use [docs/plans/TEMPLATE.md](../../../docs/plans/TEMPLATE.md). Keep the schema there, in one place.
