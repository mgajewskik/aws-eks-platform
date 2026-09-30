# Platform cost

## Budget assumptions

- Target region: Stockholm, `eu-north-1`.
- Monthly experiment budget: USD 100.
- Availability target: multiple availability zones while deployed, with regular owner-run teardown.
- Running hours: the owner's session schedule is unspecified. Include session runtime and resources retained between sessions before assessing affordability.
- The estimate below covers the VPC and bastion foundation, not the future EKS platform. A cached estimate is not an AWS spending cap.
- Cost analysis is a separate opt-in check. Required tests and CI do not call Infracost. Reuse the existing cache; explicitly request a refresh when pricing needs updating.

## Cached estimate

- Priced at: 2026-09-30
- Region: Stockholm, `eu-north-1`
- Source: Infracost CLI 2.16.3, `scripts/cost.sh`; [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for public IPv4; [EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/) for surplus T4g CPU credits
- Idle assumption: usage quantity is 0 until a row names another quantity
- Windows: 6h, 12h, 24h, 7d = 168h, 30d = 720h
- Fingerprint: b56a1da2bddd67e347db91726000fe3d81757ef72b515f20cd14e4776eead971

Infracost reported **59.3608 USD per 730-hour month**: 33.58 for one NAT gateway-hour charge, 25.112 for the `t4g.medium` bastion, and 0.6688 for its 8 GiB gp3 root disk. It scanned 52 resources (17 costed, 35 free), with six FinOps policies and zero failing. No warning or critical diagnostics. An informational diagnostic says the SSH public-key file lies outside the repository; this does not establish deployment validity. A local user-cache write warning did not prevent the scan.

This is an incomplete estimate. Infracost counted one NAT hourly charge and did not show a separate public IPv4 charge. [AWS bills regional NAT per active AZ and public IPv4 per address-hour](https://aws.amazon.com/vpc/pricing/). [Automatic NAT expansion follows workload ENIs](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateways-regional.html), so three subnets alone do not establish three active NAT AZs. The bastion occupies one AZ. The scenarios below assume one NAT public address per active AZ; confirm actual allocation after deployment. No AWS account or billing API was queried. `gitops/` and the empty EKS and registry module directories add no billable resources.

## Always-on

| Component | USD/hour | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|
| Regional NAT, per active AZ | 0.046 | 0.2760 | 0.5520 | 1.1040 | 7.7280 | 33.1200 |
| Bastion `t4g.medium` | 0.0344 | 0.2064 | 0.4128 | 0.8256 | 5.7792 | 24.7680 |
| Bastion 8 GiB gp3 | 0.00091616 | 0.0055 | 0.0110 | 0.0220 | 0.1539 | 0.6596 |
| NAT public IPv4, per address | 0.005 | 0.0300 | 0.0600 | 0.1200 | 0.8400 | 3.6000 |
| Initial scenario: one active AZ, one address | 0.08631616 | 0.5179 | 1.0358 | 2.0716 | 14.5011 | 62.1476 |
| Expanded scenario: three active AZs, three addresses | 0.18831616 | 1.1299 | 2.2598 | 4.5196 | 31.6371 | 135.5876 |

The two scenario totals are alternatives, not additive. NAT and instance hourly rates are the Infracost unit prices. The disk hourly rate is its 0.6688 USD monthly total divided by 730. Public IPv4 is 0.005 USD per address-hour, checked against AWS on 2026-09-30. The 30-day column uses 720 hours. Scenario window columns are the sum of the rounded component cells.

## Usage

| Component | Unit price | Assumed quantity | 6h | 12h | 24h | 7d | 30d |
|---|---:|---:|---:|---:|---:|---:|---:|
| NAT data processed | 0.046 USD/GB | 0 | 0 | 0 | 0 | 0 | 0 |
| VPC flow-log ingestion | 0.54 USD/GB | 0 | 0 | 0 | 0 | 0 | 0 |
| VPC flow-log archival storage | 0.028 USD/GB | 0 | 0 | 0 | 0 | 0 | 0 |
| Surplus T4g CPU credits | 0.04 USD/vCPU-hour | 0 | 0 | 0 | 0 | 0 | 0 |

The zero-usage assumption is not a promise of a zero usage bill. Bootstrapping, SSM traffic, package downloads, and flow logs generate usage. Data transfer out to the internet is not in this table. Existing S3 state storage and requests are outside the new-resource subtotal. CloudWatch Logs Insights is not enabled on the flow-log group. No additional GitOps resources are implemented in this scope.

## Delta

Compared with the 2026-09-27 estimate, the bastion change from the previous aggregate to `t4g.medium` plus 8 GiB gp3 increases the 24-hour bastion subtotal from 0.1252 USD to 0.8476 USD and the 30-day bastion subtotal from 3.7556 USD to 25.4276 USD. NAT and public IPv4 unit rates are unchanged. The initial scenario increases from 1.3492 USD to 2.0716 USD at 24 hours, and from 40.4756 USD to 62.1476 USD at 30 days. The three-AZ scenario increases from 3.7972 USD to 4.5196 USD at 24 hours, and from 113.9156 USD to 135.5876 USD at 30 days. The expanded foundation exceeds the 100 USD monthly target before usage or EKS costs. Leaving the one-AZ foundation up for 720 hours is 62.1476 USD before usage. Session hours and retained usage quantities are still unspecified, so overall affordability against 100 USD is unknown.

## Architecture comparison: ALB and NLB

This earlier ingress comparison is separate from the implemented foundation estimate above. At comparison time, `mise run cost` reused the then-empty configuration cache without calling Infracost. No billing account was queried. These load balancers are not part of the current Terraform implementation.

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
