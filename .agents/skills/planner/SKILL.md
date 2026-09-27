---
name: planner
description: Plan work as a living markdown file with binary success criteria, anti-criteria, and independent workstreams. Use when planning a feature or change, including when the conversation already contains the design.
---

# Planner

Create one **living plan file** for new work and keep it current as the picture sharpens. The file is both the implementation contract and the decision record, and it lands on disk early so a lost context never loses the plan. It scales from a single small feature to multi-lane work.

This skill produces the plan file. Read the repository's `AGENTS.md` for the workflow and use the [repository plan template](../../../docs/plans/TEMPLATE.md), including its documentation evidence section. A planning-only request stops at the plan. An existing request to implement may authorize the next stage once material decisions are settled.

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

### 4. Run the mandatory design interview

Load and use the installed global `grill-with-docs` skill for every plan, including when the user did not name it. Its global `grilling` and `domain-modeling` dependencies remain global. Do not copy these supporting skills into this repository. If a required global skill is unavailable, stop and report the missing dependency instead of silently skipping the interview.

Recover decisions already answered before asking anything. Follow the interview's rounds, record answers in this plan, and update resolved terms or qualifying ADRs as directed. A settled scope can have no unanswered questions; record that result and the existing authorization. The interview always establishes:

- What does done look like, observably? → feeds success criteria
- What must never happen? → feeds anti-criteria — every non-trivial plan needs at least one

Done when no open decision would still change the goal, criteria, or workstreams — or the user defers one, which keeps `Status: draft` with the blocker named.

### 5. Show architecture changes

Assess whether the plan changes topology, account or trust boundaries, resource ownership, connectivity, or reconciliation/data flow. If the change can be usefully shown, include a Mermaid diagram in the plan's Architecture impact section. Label current and proposed behavior, show affected boundaries and ownership, and avoid implying that proposed resources already exist. A before/after pair is useful when a single diagram hides the change.

Check that the diagram agrees with the written decisions and inspect a rendered diagram when a renderer is available. Record unavailable rendering rather than claiming it passed. If no architecture changes or a diagram cannot clarify the change, state the specific reason in that section. Update `ARCHITECTURE.md` with the implementation, not as a substitute for the plan's diagram.

### 6. Define done

Map every requirement and hard constraint to a **binary** success criterion with a concrete verification method: a command with a pass/fail signal, an observable state, or a measured threshold with units. Anti-criteria name the likely regressions, scope leaks, and forbidden shortcuts, verified by non-occurrence. Replace "works correctly"-style vagueness with observable outcomes. A criterion without a verification method keeps the plan in `draft`.

### 7. Shape the workstreams

Break the work into tracer-bullet workstreams:

- vertical slices, each independently verifiable and sized to fit one fresh context
- blocking edges declared — a workstream with no blockers can start immediately; prefactoring goes first
- small work is exactly one workstream
- every workstream maps to at least one criterion, every criterion to at least one workstream

Independent workstreams are what make a plan loopable: when they exist, flag `Loop candidate: yes` — a later loop skill can execute the plan task-by-task in fresh contexts. This skill only flags candidacy.

### 8. Confirm

Present the goal, criteria, workstreams, and validation commands. Use explicit authorization already given for this scope, or ask when a material decision remains. Record the authorization in Decisions and set `Status: ready`. For a planning-only request, stop here.

## Living file

The plan file is the single source of truth for the work: update it whenever new information lands or the plan changes shape. Status flow: `draft` → `ready` → `in progress` → `done`; `done` requires every validation check executed with evidence.

## Template

Use [docs/plans/TEMPLATE.md](../../../docs/plans/TEMPLATE.md). Keep this schema in one place so plans include the current Docs gate, Progress, and Outcomes sections.
