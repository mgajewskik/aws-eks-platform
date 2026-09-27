# Platform cost

## Budget assumptions

- Target region: Stockholm, `eu-north-1`.
- Monthly experiment budget: USD 100.
- Availability target: multiple availability zones while deployed, with regular owner-run teardown.
- Running hours: not yet priced. Include session runtime and resources retained between sessions before assessing affordability.
- The zero totals below describe today's empty configuration, not the intended HA platform. A cached estimate is not an AWS spending cap.
- Cost analysis is a separate opt-in check. Required tests and CI do not call Infracost. Reuse the existing cache; explicitly request a refresh when pricing needs updating.

## Cached estimate

- Priced at: 2026-09-27
- Region: unset
- Source: no billable resources in `platform/` or `gitops/`
- Idle assumption: usage quantity is 0 until a row names another quantity
- Windows: 6h, 12h, 24h, 7d = 168h, 30d = 720h
- Fingerprint: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

## Always-on

| Component | USD/hour | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|
| Total | 0 | 0 | 0 | 0 | 0 | 0 |

## Usage

| Component | Unit price | Assumed quantity | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|---:|
| Total |  | 0 | 0 | 0 | 0 | 0 | 0 |

## Delta

First record. No previous anticipation.

## Architecture comparison: ALB and NLB

This is the requested ingress comparison, not a complete platform estimate or a change to the empty-configuration cache above. `mise run cost` returned the same fingerprint on 2026-09-27 and did not call Infracost. No billing account was queried.

- Region: Stockholm, `eu-north-1`.
- Verified: 2026-09-27 against the public AWS ELB price list, published 2026-09-11T12:45:44Z.
- Scenario: one public and one internal load balancer, each spanning three AZs. Assume three in-use public IPv4 addresses in total. Actual public ALB address count can increase with scaling.
- Usage assumption: zero LCU/NLCU-hours, no reserved capacity. All figures are USD before tax.
- Windows: 6h, 12h, 24h, 7d = 168h, 30d = 720h. These are hours the resources exist, including idle time.

| Component | Unit rate | Quantity | USD/hour | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ALB fixed charge, alternative A | 0.02394/LB-hour | 2 | 0.04788 | 0.28728 | 0.57456 | 1.14912 | 8.04384 | 34.47360 |
| NLB fixed charge, alternative B | 0.02394/LB-hour | 2 | 0.04788 | 0.28728 | 0.57456 | 1.14912 | 8.04384 | 34.47360 |
| Public IPv4, either alternative | 0.005/address-hour | 3 | 0.01500 | 0.09000 | 0.18000 | 0.36000 | 2.52000 | 10.80000 |
| Fixed subtotal, A or B plus IPv4 | | | 0.06288 | 0.37728 | 0.75456 | 1.50912 | 10.56384 | 45.27360 |

The alternatives are mutually exclusive; do not add the ALB and NLB rows together. The internal load balancer uses private addresses. Sources: [Stockholm ELB price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSELB/current/eu-north-1/index.json), [public IPv4 pricing](https://aws.amazon.com/vpc/pricing/).

| Usage component | Unit rate | Assumed quantity | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|---:|
| ALB capacity, alternative A | 0.0076/LCU-hour | 0 | 0 | 0 | 0 | 0 | 0 |
| NLB capacity, alternative B | 0.0057/NLCU-hour | 0 | 0 | 0 | 0 | 0 | 0 |

LCU and NLCU meters differ. Their rates alone do not determine which will cost less for actual traffic. Source: [ELB metering](https://aws.amazon.com/elasticloadbalancing/pricing/). Verified SKU pairs are `FY6N7P3VBQKBHGCC` and `TRECDNRTVX6SSW4U` for base hours, and `3T8FA94JAYX6F8NU` and `5PCGKRZDNVWXYNVZ` for capacity.

Relative to the empty configuration, either ingress scenario adds 1.50912 USD at 24h and 45.27360 USD at 30d under these assumptions. This excludes EKS, nodes, NAT, DNS, certificates, secret storage, logging, data transfer, and taxes. Total platform affordability against the flexible 100 USD monthly target remains unknown. Deleting load balancers between experiments removes their subsequent hourly charges; merely sending no traffic does not.

## Certificate alternatives under consideration

Prices checked 2026-09-27 from [AWS Certificate Manager pricing](https://aws.amazon.com/certificate-manager/pricing/). These are alternatives, not selected resources or additions to the subtotal above.

| Alternative | Current charge basis | Lifecycle consequence |
|---|---|---|
| ACM public non-exportable | No certificate fee for integrated AWS services | Cannot deliver its private key to Envoy; use changes TLS termination to an AWS listener. |
| ACM ACME | First tier: 1 USD per FQDN occurrence or 5 USD per wildcard occurrence issued; first 30,000 ACME API calls per account/month free | ACME client still retains keys and renews; rebuilding and ordering again incurs fresh issuance charges. |
| Standard ACM exportable public certificate | 7 USD per FQDN or 79 USD per wildcard at issuance and again at renewal | Certificate resource can persist across clusters; ESO exports it into gateway TLS Secrets. Two separate wildcard names cost 158 USD at each issuance/renewal event. |

Exportable ACM includes the first 10,000 export calls per account/month without an API charge. Renewal eligibility and delivery still need attention during prolonged cluster absence. A retained Let's Encrypt client avoids paid ACM issuance, but secret storage, API usage, and any retained renewal runner need pricing once chosen. No full certificate-lifecycle total is claimed.

The owner selected retained Let's Encrypt issuance and Secrets Manager/ESO delivery after this comparison, then accepted one wildcard and scheduled Lambda renewal in Q17. Paid ACM rows are alternatives, not planned charges. Scheduler, Lambda, durable client-state storage, secret storage/API use, and monitoring remain unpriced until implementation sizing is defined. These retained services continue to exist between EKS sessions; certificate issuance being free does not make the renewal system free.
