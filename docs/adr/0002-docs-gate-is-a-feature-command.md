---
status: accepted
date: 2026-09-07
---

# Run the Docs gate as a Feature command, not inside `checks`

## Context and Problem Statement

A Feature is not done until its documentation contract is met. That rule must be a command that can fail, not only prose in `AGENTS.md`. Putting the same command in `mise run checks` would fail ordinary commits that do not close a Feature (typos, pin bumps).

Implementation update, 2026-09-27: the local implementer workflow fills evidence and a fresh independent reviewer verifies it.

## Considered Options

* Docs-gate only as an `AGENTS.md` instruction
* Docs-gate inside `mise run checks` / pre-commit
* Separate `mise run docs-gate --plan <file>` plus an `AGENTS.md` hard rule and a custom skill; reviewer PASS-gate as backstop

## Decision Outcome

Chosen option: "Separate `mise run docs-gate -- --plan <file>`", because it is a red loop at Feature close and does not punish every commit. Extra `--` is required so mise forwards `--plan` to the script.

`mise run checks` stays mechanical (fmt, validate, TFLint, Trivy, and later yaml/shell/link checks). The implementer runs `docs-gate` when moving a Feature to `done`; an independent reviewer checks the evidence. The local `.agents/skills/docs-gate/` skill explains how to fill the plan checklist. Pre-commit does not run docs-gate.

### Consequences

* Good, because Feature close has a failing command, not only a suggestion.
* Good, because typo commits and CI on every push can stay green without fake doc edits.
* Bad, because an agent can still check boxes dishonestly; the reviewer PASS-gate is the backstop, not a smarter shell script.

### Confirmation

* `mise run checks` does not invoke docs-gate.
* `AGENTS.md` names `mise run docs-gate -- --plan <file>` as required to mark a Feature `done`.
* Plan template includes a Docs gate checklist with skip-reasons.

The checker now requires all six categories, existing repository-file evidence with an explanation, or a specific skip reason. Plan evidence must name the supplied plan, which must contain Progress and Outcomes. Pytest regression tests reject missing categories, empty skips, and escaping evidence paths. Mechanical checks do not establish semantic accuracy; independent review still verifies the content.
