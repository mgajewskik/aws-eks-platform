---
status: accepted
date: 2026-09-27
---

# Bootstrap Argo CD and Karpenter with Terraform

## Context and Problem Statement

Argo CD reconciles cluster software and Karpenter provisions workload compute. Both are foundational services whose installation depends on AWS resources and cluster configuration. The owner wants Terraform to supply those details directly rather than publishing an indirect configuration handoff through GitOps or a secret store.

## Considered Options

* Terraform installs Argo CD; GitOps installs Karpenter using a shared configuration contract.
* Terraform installs both foundational controllers and supplies their infrastructure-derived configuration directly.

## Decision Outcome

Chosen option: "Terraform installs both foundational controllers", because Argo CD and Karpenter are part of the platform bootstrap.

Terraform owns the Argo CD and Karpenter installations and their AWS prerequisites. Values such as cluster identity, IAM configuration, and Karpenter discovery settings flow directly from Terraform-managed infrastructure into the bootstrap configuration. These values do not need to pass through External Secrets Operator.

GitOps owns the remaining cluster software and workloads. It must not also reconcile the Terraform-owned Argo CD and Karpenter installations. External Secrets Operator remains a candidate for workload credentials, rather than a transport for bootstrap Helm values.

Independent seed compute must exist before either controller starts. Karpenter cannot be the only means of creating the nodes needed to run its own controller.

The owner subsequently confirmed that Terraform also owns the baseline EC2NodeClass and NodePool. Terraform supplies their infrastructure-derived values and applies the resulting Kubernetes objects. The rendering mechanism remains an implementation choice; it must preserve Terraform ownership rather than leave an untracked shell-applied manifest. Plan these custom resources only after their CRDs exist.

The owner selected one initial managed system node provisioned without Karpenter, with one Karpenter controller replica and compatible non-HA Argo CD settings. Require scheduling the Karpenter controller and required Argo CD components onto that system capacity. Karpenter scale-down must not remove this node. This does not promise immunity from node failure, pressure eviction, upgrades, or owner-run teardown. Additional system nodes remain a later availability improvement.

### Consequences

* Terraform can connect the controllers to their AWS dependencies without duplicating computed configuration in Git.
* Controller version changes use the Terraform workflow rather than Argo CD self-management or GitOps upgrades.
* Bootstrap and teardown need ordered stages and working private API access from the owner's machine.
* GitOps workloads and their controller-owned AWS resources must be cleaned up while the controllers and cluster still exist.

### Confirmation

Review the eventual ownership map and Terraform plan for both controller installations, their configuration inputs, independent seed compute, and baseline NodePool/EC2NodeClass. Verify that GitOps does not manage the same objects and that controller placement excludes Karpenter-managed nodes. No controller is installed by this ADR.

See the [foundation architecture plan](../plans/2026-09-27-private-eks-foundation.md).
