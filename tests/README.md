# Tests

All tests use pytest, with dependencies locked by uv. CLI tools such as Terraform are validators that pytest may call.

| Layer | Status | Scope |
|---|---|---|
| Harness (`tests/harness/`) | Implemented | Default collection. Check dispatch, plan policy and plan script, cost cache check, Terraform variables, and access scripts. No credentials or cloud access. |
| Terraform | Implemented in checks | Format, validate, TFLint, and Trivy. Native `.tftest.hcl` tests are not used. |
| Plan policy | Implemented | `mise run plan` checks the resolved plan before saving it for apply. Read-only credentials. |
| Live (`tests/live/test_deployed.py`) | Implemented | `mise run verify-live`: no drift, bastion reachable only through SSM, flow logs delivered. Read-only; verifies account and Region first. |
| Controller leftovers | Planned | Added with the first controller that provisions AWS resources: nothing tagged for the cluster remains after destroy. |
| GitOps and policy | Planned | Render manifests, validate schemas, and assert allowed and denied policy examples. Credential-free. |
| Workload scenarios | Out of scope | Cases that create or change live resources. |

```bash
mise run test-harness     # harness only
mise run checks           # harness plus Terraform and security checks
mise run verify-live      # after apply
```

Tests never apply or destroy the platform; Terraform lifecycle is never a fixture. Live cases check what the plan policy cannot see, such as changes made outside Terraform and runtime behavior, rather than repeat it. Interactive SSH and tunnel checks are in the [bastion runbook](../docs/runbooks/vpc-bastion.md).
