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
