---
name: docs-gate
description: Feature-close documentation contract. Use when marking a Feature done, filling a plan Docs gate section, or evaluating whether ARCHITECTURE, runbooks, ADRs, CONTEXT, or README must change.
---

# Docs gate

A Feature is not done until its documentation contract is met. This skill is judgment. The red loop is `mise run docs-gate -- --plan <file>` (ADR-0002). Do not run this on every commit. Do not put it in pre-commit.

Load when Status would become `done`, or when filling the plan's **Docs gate** section.

## Steps

1. Open the living plan. Completion: the plan path is known and the file exists.
2. Fill exactly one item for each label: `Plan`, `Architecture`, `Runbook`, `ADR`, `Glossary`, `README`. Check it as `- [x] Label: evidence: <repo-relative-file> | <specific description>`, or leave an optional category unchecked as `- [ ] Label: skip: <specific nonempty reason>`. The Plan item cannot be skipped and must point to this plan. Evidence files must exist inside the repository. Completion: no bare or duplicate items.
3. Run `mise run docs-gate -- --plan <file>`. Completion: exit 0.
4. The implementer runs `mise run checks` and verifies every plan criterion and anti-criterion. The independent reviewer checks that evidence under `AGENTS.md`. Completion: Feature may move to `done` only when checks are green and review returns `Decision: PASS`.

## Items

| Item | Check when | Skip when |
|---|---|---|
| Plan Progress and Outcomes | Feature is closing; evidence is the supplied plan itself | never on close |
| `ARCHITECTURE.md` | topology, trust boundary, or "where a change belongs" changed | skip: no architecture change |
| Runbook | an operator procedure changed (apply, bootstrap, break-glass) | skip: no ops procedure change |
| ADR | hard-to-reverse + surprising + real trade-off | skip: 3-part test not met |
| `CONTEXT.md` | a term resolved | skip: no new term |
| `README.md` | public surface changed (what it is, how to clone, layout) | skip: no public surface change |

Skip reasons and evidence descriptions must be specific. Empty text, template placeholders, and `later` are not reasons. The command checks checklist structure and evidence-file existence. It cannot prove that a document says the right thing or that a skip is justified; the reviewer checks those claims against the change.

## Not this skill

- Mechanical fmt/validate/Trivy — `mise run checks`
- Per-commit hooks
- Inventing a runbook or ADR so the boxes are checked
