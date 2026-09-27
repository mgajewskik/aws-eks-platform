# <Feature title>

Save as `docs/plans/YYYY-MM-DD-<kebab-slug>.md`. Keep this plan current as decisions and evidence change.

**Status:** draft
**Loop candidate:** no
**Date:** YYYY-MM-DD

Status flow: `draft` → `ready` → `in progress` → `done`. A Feature reaches `done` only after its criteria, anti-criteria, validation, and Docs gate pass.

## Goal

<Observable outcome from the user's perspective.>

### Success criteria

- [ ] C1: <Binary result and how to verify it.>

### Anti-criteria

- [ ] A1: <Forbidden outcome or regression and how to check its absence.>

## Context & References

- <Inspected path or source and why it matters.>

## Decisions

- <Outcome of the mandatory global grill-with-docs interview, including settled decisions and open questions.>
- <Decision, reason, and relevant rejected alternative.>

## Architecture impact

<State whether topology, trust/account boundaries, ownership, connectivity, or reconciliation/data flow changes. If a diagram clarifies the change, include a Mermaid diagram here with current/proposed labels and affected boundaries. Otherwise state why a diagram is not applicable. Record rendering validation or its limitation.>

## Workstreams

Small work has one workstream. Each criterion belongs to a workstream; list blocking edges when workstreams can run independently.

### WS-1: <Title>

**Delivers:** <End-to-end behavior>
**Blocked by:** None
**Seams:** <Interface under test, if applicable>

- [ ] <Verifiable slice>

## Validation

- `<command or observation>` → proves <criterion>

## Out of Scope

<What this plan excludes.>

## Docs gate

At Feature close, replace each line with exactly one of:

- Checked: `- [x] Label: evidence: <repo-relative-file> | <specific description>`
- Unchecked optional category: `- [ ] Label: skip: <specific nonempty reason>`

The Plan item must be checked and point to this plan. Evidence files must exist inside the repository. The command checks format and file existence; the reviewer checks whether the evidence and skip decisions are true. Run `mise run docs-gate -- --plan <this-file>` before setting Status to `done`.

- [ ] Plan:
- [ ] Architecture:
- [ ] Runbook:
- [ ] ADR:
- [ ] Glossary:
- [ ] README:

## Progress

<Dated work and validation notes.>

## Outcomes

<What shipped, validation result, and remaining limits.>
