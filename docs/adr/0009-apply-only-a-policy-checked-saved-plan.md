---
status: accepted
date: 2026-10-08
---

# Apply only a saved plan that passed the plan policy

## Context and Problem Statement

Apply generated a fresh plan with `-auto-approve`, so nothing reviewed or checked before apply bound what it changed. The goal is to let agents later deploy and tear down without the owner, which needs a gate that every apply passes.

## Considered Options

* Fresh plan with `-auto-approve` (previous)
* Saved plan, reviewed by a person
* Saved plan that `mise run plan` keeps only when a policy over its JSON passes
* Trivy or OPA over the plan JSON

## Decision Outcome

Chosen option: "Saved plan kept only when the policy passes". `scripts/plan.sh` writes the plan to a temporary directory, exports its JSON, and runs `scripts/plan_policy.py`. Only then does it move the plan to `platform/tfplan`. `mise run apply` applies that file. Teardown is a `-destroy` plan through the same gate.

Trivy over plan JSON cannot apply the per-resource exceptions the source scan records inline. OPA would add a tool and a language for a few rules.

### Consequences

* Good, because what was verified is exactly what applies, and Terraform rejects a plan once state has changed.
* Good, because one gate covers deploy and teardown, which autonomous runs need.
* Bad, because plan files hold sensitive values in plain text; they are written owner-only, ignored by Git and the secret scan, and deleted after apply.
* Bad, because the policy covers only resource types it knows; each new type needs its invariants added.
