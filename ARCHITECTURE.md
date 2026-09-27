# Architecture

This is the target ownership map, not a deployed inventory. Workflow rules live in [AGENTS.md](AGENTS.md); terms live in [CONTEXT.md](CONTEXT.md).

## Current implementation

`platform/main.tf` is empty. No GitOps manifests or platform modules are implemented. The working capabilities are local checks, pytest harness tests, and agent workflow documentation.

## Target and ownership

The platform runs in one AWS account in Stockholm, `eu-north-1`. It must support workloads across availability zones while deployed. Deployment and teardown are local, owner-run operations. The monthly experiment target is USD 100; affordable runtime depends on the eventual topology and retained resources.

An optional connection can attach the platform VPC to a transit gateway owned by a separate networking account. Standalone operation must not require that account. The networking owner controls sharing, attachment acceptance where required, and transit-gateway routing; the platform owner controls its VPC attachment and VPC routes. Neither attachment existence nor a route in one account proves end-to-end connectivity. See [AWS transit gateway sharing](https://docs.aws.amazon.com/vpc/latest/tgw/working-with-transit-gateways.html).

| Owner | Resources and configuration |
|---|---|
| Terraform in `platform/` | VPC, EKS, IAM, registry, state backend, and platform-side network integration |
| GitOps YAML in `gitops/` | Cluster add-ons, workloads, policy, and resource requests |
| Kubernetes controllers | AWS resources provisioned from those requests, such as ALBs and EBS volumes |
| Networking account | Shared transit gateway and its routing/acceptance policy |
| Owner's local machine | Deployment, teardown, explicitly selected live scenarios |

Terraform and controllers must never manage the same AWS resource. An Ingress or PVC can request a controller-owned resource while Terraform owns the cluster and controller identity. See [ALB integration](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) and [EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).

Environment differences use variable values rather than copied Terraform trees. Secret values stay outside Git and tfvars; cluster consumers reference secrets through the chosen AWS integration.

## Decisions required before the first deployment

The first platform plan must define AZ/node capacity, private API access from the local runner, egress, state/bootstrap ownership, GitOps reconciliation, and policy enforcement. It must price these choices before promising affordable uptime.

The acceptance criteria need observable workload availability, least-privilege identities, network isolation, encrypted storage, secret access, logging, upgrade/recovery procedures, and cleanup outcomes. "Production ready" is not a substitute for those checks. Regular teardown also needs a rule for what persists, including state, logs, snapshots, and volumes.

GitOps bootstrap has not been selected. Its first plan must name how the controller is installed and how ownership transfers to reconciliation without Terraform and GitOps managing the same objects.

## Verification boundary

All tests use Python/pytest and uv-managed dependencies. Required checks are credential-free and do not access a live cluster. Future read-only tests inspect a manually deployed platform. Separate user-run scenarios prove policy behavior and ALB/EBS provisioning and cleanup.

See [the testing strategy](docs/research/2026-09-27-eks-testing-strategy.md) and [test execution contract](tests/README.md). Cross-account networking and availability claims require live evidence when those capabilities are implemented.
