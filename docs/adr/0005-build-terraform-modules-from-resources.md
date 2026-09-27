---
status: accepted
date: 2026-09-27
---

# Build Terraform modules from provider resources

## Context and Problem Statement

This platform is a learning project. The owner wants to understand each resource, dependency, and lifecycle inside its Terraform modules. Using a prebuilt VPC or EKS module would hide part of the work the project is intended to teach.

## Considered Options

* Consume third-party Terraform modules from a registry or Git repository.
* Copy a prebuilt module into this repository and maintain it locally.
* Author repository-owned modules from Terraform provider resource blocks.

## Decision Outcome

Chosen option: "Author repository-owned modules from Terraform provider resource blocks", because learning the internals is an explicit goal.

All Terraform child modules are written from scratch in this repository and referenced through local paths. Do not consume remote modules or vendor prebuilt modules as a shortcut. Provider plugins remain the mechanism for managing AWS and bootstrap resources; this decision does not require writing custom providers.

Start with the resources needed for this platform. Do not reproduce a general-purpose module's options or abstraction layers. The first module will describe the agreed VPC topology directly.

### Consequences

* Resource ownership, routing, permissions, and dependencies remain visible for study and review.
* The repository owns compatibility, testing, security checks, and maintenance that an external module would otherwise provide.
* Implementation takes longer, and resource coverage must be checked explicitly rather than inferred from a module's reputation.

### Confirmation

During implementation review, inspect every Terraform `module` source: each must resolve to repository-owned code authored for this project. Verify the module's resources and behavior through the repository's pytest and CLI checks. No modules are implemented at the time of this decision.

See the [foundation architecture plan](../plans/2026-09-27-private-eks-foundation.md).
