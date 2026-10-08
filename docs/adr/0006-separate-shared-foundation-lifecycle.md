---
status: accepted
date: 2026-09-27
---

# Keep shared account resources in a separate Terraform state

## Context and Problem Statement

The owner destroys the EKS platform between deployment sessions. Deleting the image cache would force new upstream image downloads on the next deployment. Recreating public DNS delegation would also disrupt a namespace intended for other applications in the account.

## Considered Options

* Keep all resources in the disposable platform state and recreate them each session.
* Manage retained resources in a separate CloudFormation stack.
* Use a separate Terraform root and state for retained resources.

## Decision Outcome

Chosen option: "Use a separate Terraform root and state for retained resources", because the shared foundation has a different lifecycle and the project already uses Terraform.

Use `platform/shared/` for the shared foundation. The name describes reuse and retention across deployment sessions; it does not imply that every resource is region-global. The ECR cache remains regional in Stockholm.

This root owns the ECR cache configuration, the public Route 53 platform zone (for example `aws.example.com`), and that zone's delegation records in the existing Cloudflare parent zone. Use the Cloudflare provider for those NS records. The parent zone and its unrelated records remain outside this root's ownership.

The disposable platform uses independent state and does not own the shared resources. Workload DNS records and controller-created load balancers still follow their workloads and need cleanup before their controllers are removed. Persistent public DNS does not imply that a VPC-associated private zone must survive deletion of that VPC.

The existing state bucket is a prerequisite outside routine platform teardown. Verify its controls before use; this decision does not import it or change its configuration.

### Consequences

* Cached images and public delegation survive an ordinary platform teardown.
* The owner maintains separate state keys and deployment operations, and retained resources continue to incur charges.
* Cloudflare access is required when managing the delegation. Limit its token to the parent zone and keep the credential outside Git and Terraform values stored in state.
* Separate state reduces accidental lifecycle coupling, but does not prevent an authorized operator from explicitly deleting shared resources.

### Confirmation

Implementation review must verify that the disposable state does not own ECR repositories, the shared public zone, or the parent delegation records. A later owner-run teardown check verifies that these resources survive and workload records and load balancers are removed. No Terraform root or cloud resource is implemented by this ADR.

See the [foundation plan](../plans/2026-09-27-private-eks-foundation.md) for provider, credential, and bootstrap decisions still open.
