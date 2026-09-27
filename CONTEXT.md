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

**Public application**:
A workload deliberately exposed to internet clients to provide or demonstrate a platform service.
_Avoid_: an operator application, the Kubernetes API

**Operator application**:
A platform interface, such as Argo CD or Grafana, intended for the owner's private administrative access.
_Avoid_: a public application, a service made private only by an unadvertised name

**Shared foundation**:
Account resources retained across deployment sessions and reused by the platform or other deployments in the same account.
_Avoid_: resources necessarily global across AWS Regions, the disposable platform, cluster bootstrap

**System node**:
A node reserved for foundational platform services whose availability must not depend on workload autoscaling.
_Avoid_: a node guaranteed never to fail or be evicted, a Karpenter-managed workload node

**Retained certificate state**:
The certificate chain, private key, and ACME account/renewal state preserved independently of a disposable cluster.
_Avoid_: retained application data, a certificate that never expires, a public certificate without its matching private key

**Split-view DNS**:
Public and VPC-associated private hosted zones for the same domain, each with an explicitly managed record set.
_Avoid_: automatic fallback from a missing private record to the public zone, certificate-based access control
