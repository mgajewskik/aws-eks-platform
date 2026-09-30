# Tests

Run the local harness regression tests with `rtk proxy mise run test-harness`. The task invokes `uv run --locked --no-sync --no-env-file pytest`. [`pyproject.toml`](../pyproject.toml) selects `tests/harness` by default, and [`uv.lock`](../uv.lock) records the Python dependencies. Bootstrap those dependencies separately with `rtk proxy uv sync --locked`; required checks do not sync or install packages. The harness tests need no AWS credentials or Kubernetes context.

Run the required repository checks with `rtk proxy mise run checks`. That command needs no cloud credentials and must not deploy the platform, run live tests, or call Infracost. Mise loads `.env.local` for every local task; uv's `--no-env-file` does not remove that inherited environment. Never print its values in tests or reports. Terraform initialization and Trivy checks may use the network to fetch tool data. Pytest is the sole test runner, including for future platform tests; CLI tools remain validators or renderers that pytest can call.

Future platform tests belong in separate layers:

| Layer | Entry and scope |
|---|---|
| Terraform module checks | Keep Terraform format, validate, TFLint, and Trivy in required checks. Add pytest assertions over safe local artifacts only when modules provide meaningful cases. Native `.tftest.hcl` files are not adopted. Do not make a credentialed Terraform plan or platform lifecycle part of tests. |
| GitOps and policy tests | Add pytest cases that render manifests, validate schemas, and assert allowed and denied policy examples after the GitOps and policy engines are selected. Keep them credential-free. |
| Read-only live tests | Add explicit pytest paths after manual deployment. Require AWS account, `eu-north-1` region, cluster identity, and Kubernetes context checks before AWS or cluster reads. Keep those paths outside the default selection, `mise run checks`, and CI. Add Python packages through uv when needed. |
| Temporary workload scenarios | The owner explicitly runs bounded pytest cases for policy admission, ALB, EBS, or network traffic. Name the resources, then verify both Kubernetes and AWS cleanup. Never use Terraform apply or destroy as test setup or teardown. |

The harness now checks local VPC configuration policies. It does not prove deployment, SSM/SSH connectivity, DNS routing, tunnel cleanup, or availability. The owner-run acceptance steps are in the [VPC and bastion runbook](../docs/runbooks/vpc-bastion.md); no bespoke live bastion pytest suite is required. The [testing research](../docs/research/2026-09-27-eks-testing-strategy.md) compares broader test layers, evidence, cost, and cleanup limits.
