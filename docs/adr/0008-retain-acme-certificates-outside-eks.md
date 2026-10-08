---
status: accepted
date: 2026-09-27
---

# Retain ACME certificates outside disposable EKS

## Context and Problem Statement

The platform may be destroyed and rebuilt several times per week. Issuing a new production certificate on each rebuild can exhaust CA limits. TLS terminates at Istio gateways, so the cluster needs a certificate chain and matching private key. The owner prefers the cheaper retained Let's Encrypt option over paid ACM issuance.

## Considered Options

* Issue certificates inside every replacement cluster with disposable issuer state.
* Retain Let's Encrypt ACME state outside EKS and deliver existing certificates to each cluster.
* Retain paid exportable ACM certificates and export them into EKS.

## Decision Outcome

Chosen option: "Retain Let's Encrypt ACME state outside EKS", because certificate issuance must follow certificate lifecycle rather than cluster lifecycle, without paid ACM issuance.

Retain the certificate, full chain, matching private key, and required ACME account/renewal state independently of the cluster. Store the published TLS bundle in AWS Secrets Manager. GitOps-managed External Secrets Operator reads it into the Istio gateway namespaces. Terraform owns secret containers and IAM, never secret values. One external renewal workflow writes the published bundle; EKS consumers have read-only access.

Certificate retention is an explicit exception to disposable application data. No cert-manager installation is required for this ingress certificate path. Istio workload identity remains a separate system with its own certificate rotation.

On 2026-09-27 the owner accepted one wildcard for the platform zone (for example `*.aws.example.com`), single-level application names, public/private split-view DNS, and scheduled Lambda renewal outside the disposable VPC. The architecture document explains the DNS consequences; separate implementation plans must prove Lambda state recovery, renewal, and delivery behavior.

### Consequences

* Rebuilding EKS reuses a valid certificate without creating a new ACME order.
* Renewal must continue independently of the disposable cluster and needs failure/expiry monitoring.
* Retained secrets and any renewal runner still incur costs; free certificate issuance does not imply a free lifecycle.
* A wildcard shared between public and private gateways expands the impact of a leaked private key. Only gateway workloads may consume it.
* DNS-01 remains necessary for a Let's Encrypt wildcard. Only challenge records are public; private application endpoints remain private.

### Confirmation

Before production use, prove staging issuance, durable state recovery, no new order on a rebuild with a valid certificate, renewal publication, and the certificate actually served by both gateways. A failed renewal must preserve the last valid published bundle and report failure. Verify no private keys enter Git, Terraform state, logs, or deployment outputs.

See the [architecture](../../ARCHITECTURE.md) and [living plan](../plans/2026-09-27-private-eks-foundation.md). This ADR records a decision, not deployed infrastructure.
