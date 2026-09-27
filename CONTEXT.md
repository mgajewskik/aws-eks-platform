# AWS EKS Platform

## Language

**Harness**:
The repository's agent workflow, check commands, and documentation contracts.
_Avoid_: the EKS cluster, a required external skill collection

**Platform**:
The AWS EKS system built by this repository, including its network, cluster, cluster software, and desired workload state.
_Avoid_: the Terraform directory as a name for the whole system

**Feature**:
One shippable platform capability tracked by a living plan and its acceptance evidence.
_Avoid_: commit, individual file change

**Docs gate**:
The Feature-close contract for documentation evidence and reviewed skip reasons.
_Avoid_: proof that prose is accurate, automatic prose generation, a pre-commit hook

**Environment**:
One named deployment of the platform, distinguished by its parameter values.
_Avoid_: a copied Terraform tree

**Platform account**:
The AWS account that owns a platform deployment.
_Avoid_: the networking account

**Networking account**:
A separate AWS account that owns shared network connectivity used by other accounts.
_Avoid_: a required account for standalone operation

**Controller-owned resource**:
An AWS resource whose lifecycle follows a request reconciled by a Kubernetes controller.
_Avoid_: a second Terraform-managed copy of the same resource

**Deployment session**:
The period during which the platform is deployed for an experiment.
_Avoid_: a billing month, a test fixture that creates the platform
