---
status: accepted
date: 2026-09-07
---

# Commit Environment tfvars; keep secrets in Secrets Manager

## Context and Problem Statement

`platform/vars/dev.tfvars` will hold Environment parameters (account ID, prefix, CIDRs). The owner considered SOPS+PGP so the account ID would not appear in a public repo, after reading [Pocwierz, 2024](https://medium.com/@maciej.pocwierz/how-an-empty-s3-bucket-can-make-your-aws-bill-explode-934a383cb8b1) (empty bucket billed for ~100M unauthorized PUTs).

That incident was **guessable bucket name** + S3 charging the owner for 403s. It was not "someone knows the account ID." AWS stopped charging owners for external `AccessDenied` on 2024-05-13 ([what's new](https://aws.amazon.com/about-aws/whats-new/2024/05/amazon-s3-no-charge-http-error-codes/)). Account IDs are not classified secret ([account identifiers](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html)).

SOPS-encrypting tfvars was therefore the wrong control for that threat.

## Considered Options

* SOPS+PGP on tfvars (YubiKey)
* Gitignore real tfvars
* Commit plaintext parameter tfvars; put secret *values* in Secrets Manager and pass ARNs

## Decision Outcome

Chosen option: "Commit plaintext `platform/vars/dev.tfvars`; never put secret values in git", because parameters are not secrets, apply is laptop-only (ADR-0003), and Secrets Manager (created in the UI or by Terraform as a container, value set out of band) is the place for credentials.

Also: S3 bucket names use a unique prefix plus enough entropy (random suffix). Do not use short or common names. That is the control Pocwierz actually recommended. Do not put secret values in tfvars even later; prefer Secrets Manager over SOPS unless a secret has no AWS home and must live in git.

### Consequences

* Good, because the toolchain stays simple: no decrypt on apply, CI can validate without a YubiKey.
* Good, because secret values never hit git or Terraform variables.
* Bad, because the AWS account ID is public in this repo. That is accepted.
* Bad, because a guessable state-bucket name can still attract misconfigured clients; entropy in the name is mandatory.

### Confirmation

* `platform/vars/dev.tfvars` is committed and contains no passwords, tokens, or access keys.
* No `.sops.yaml` in this decision.
* State and log buckets are not short dictionary names.
