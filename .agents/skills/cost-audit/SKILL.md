---
name: cost-audit
description: Price this platform when a major billable change is not already cached in docs/cost.md, and when asked what a deploy will cost or what AWS has already charged. Reuses the cached totals instead of calling Infracost again.
---

# Cost audit

`docs/cost.md` is the only place USD totals live, including the price fingerprint and budget assumptions. Cost analysis is separate and opt-in; required checks, tests, pre-commit, and GitHub Actions never call Infracost. Infracost runs only through `mise run cost`. `.env.local` is the repo env file, loaded by mise for every command in this repo. Reuse existing results to conserve the account's monthly run allowance.

Two branches. Run the one this turn picked.

## Pick

1. Read the diff (staged, else the working tree) and the question. A change is major when it adds, removes, or resizes a billable component (the price lines `scripts/cost.sh` hashes). Tags, names, IAM, security groups, docs, and formatting are not major. Completion: the branch is estimate, bill, or skip.
   - **Estimate** — the change is major, or the user asks what a deploy will cost.
   - **Bill** — the user asks what AWS has already charged for a deployed platform.
   - **Skip** — the diff is not major. Say skip and point at the cached totals.

## Estimate

Anticipation is the cost of keeping the platform up, plus usage at a stated quantity. Idle quantity is 0.

1. List every billable component Terraform or GitOps will create. Read counts and sizes from `platform/` and `platform/vars/*.tfvars`. Completion: each component is always-on, usage, or both. Always-on bills per hour while the resource exists, including at idle. Usage bills per byte, request, or capacity unit. NAT, a load balancer, and a public address often have both; those are two rows. IAM, security groups, and the VPC itself are not rows. Region comes from the provider or tfvars. Stop before pricing when the region is absent.
2. Run `mise run cost` once. A cache hit reuses `docs/cost.md` and does not call Infracost. A cache miss calls Infracost once and prints a fingerprint. Price any billable GitOps line that scan did not cover from the AWS Price List. Divide a 730-hour Infracost month by 730 to get the hourly rate. Run `mise run cost -- refresh` only when the user asks to refresh prices. Completion: every component has a unit price, the source, and the date fetched. A missing price stops the audit. Record list price. Note free-tier eligibility only when that same source states it.
3. Set usage quantity to 0 unless the user stated a quantity. Name that assumption on the row and scale it to each window. Completion: every usage row has a quantity, including 0.
4. Always-on USD for a window is the hourly rate times the hours. The windows are 6, 12, 24, 168 (column `7d`), and 720 (column `30d`). Write that legend at the top of `docs/cost.md`. Completion: the file has an Always-on table and a Usage table with those columns, plus region, priced-at date, source, and the legend.
5. Compare the new always-on totals at 24h and 30d with the totals already in `docs/cost.md`. Use `git show HEAD:docs/cost.md` when the file is dirty. Compare usage at 30d when any quantity is non-zero. Completion: the reply names each increase as component, window, old USD, new USD. A first file has no increase.
6. Write `docs/cost.md` before the reply, including the fingerprint `mise run cost` printed, and include the file in the same commit when Terraform or GitOps is changing. Completion: the file's totals equal the totals just computed, and its fingerprint equals the one just printed. A cache hit leaves the file unchanged. A higher total is a warning the human sees. Compare the planned session hours plus retained-resource costs with the USD 100 monthly target. Missing runtime or retention assumptions mean affordability is unknown. An estimate does not enforce an AWS spending cap.

## Bill

1. Run when the user asked for the deployed cost. This is laptop-only, with AWS credentials, the same opt-in class as `terraform plan`. Completion: a tag or resource filter taken from this repo's Terraform. Stop when that filter cannot be built. An account-wide total is not this platform.
2. Read Cost Explorer for the last 24 hours and the last 30 days under that filter. Use the console or `aws ce`, after reading `aws ce --help` for the current flags. Completion: `docs/cost.md` gains a Bill section with the window, the filter, the date, and the USD. The Always-on and Usage tables stay as anticipation.
3. Warn when a bill window is above the matching anticipation total. Completion: the reply states bill versus anticipation for 24h and 30d.

## File rules

Rates, quantities, totals, region, source, and date belong in `docs/cost.md`. Account ids, tokens, and bill exports stay out of the file.
