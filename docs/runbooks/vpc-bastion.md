# Deploy and connect to the VPC bastion

| Outcome | Tools | Permissions | Stop when |
|---|---|---|---|
| Deploy the VPC, verify SSM/SSH and a VPC-only tunnel, then tear down | Pinned Terraform, AWS CLI, jq, uv, ssh, sshuttle, Session Manager plugin | S3 state access, Terraform resource permissions, SSM session/describe | Account, bucket, plan, or live target does not match |

Owner-run, from the repository root. Agents may run the read-only checks, `mise run plan`, and `mise run verify-live`; apply and sessions are owner-run. Deployment values come from `platform/default.tfvars` and `platform/backend.s3.hcl`. `mise run apply` applies the plan saved by the last `mise run plan` without a prompt and changes billable resources. Check [cost](../cost.md) before leaving resources running.

## 1. Preflight

Install pinned tools and the Python environment if needed. This writes local caches only. The `session-manager-plugin` is installed outside this repository and must be on `PATH`.

```bash
mise install
mise exec -- uv sync --locked --no-python-downloads
```

Check the caller account and the state bucket controls:

```bash
ACCOUNT=$(sed -n 's/^account_id *= *"\(.*\)"/\1/p' platform/default.tfvars)
REGION=$(sed -n 's/^region *= *"\(.*\)"/\1/p' platform/default.tfvars)
BUCKET=$(sed -n 's/^bucket *= *"\(.*\)"/\1/p' platform/backend.s3.hcl)
aws sts get-caller-identity --query Account --output text
aws s3api get-bucket-location --bucket "$BUCKET" --expected-bucket-owner "$ACCOUNT" --query LocationConstraint --output text
aws s3api get-bucket-versioning --bucket "$BUCKET" --expected-bucket-owner "$ACCOUNT"
aws s3api get-bucket-encryption --bucket "$BUCKET" --expected-bucket-owner "$ACCOUNT"
aws s3api get-public-access-block --bucket "$BUCKET" --expected-bucket-owner "$ACCOUNT"
grep -qF "$(ssh-keygen -y -f ~/.ssh/aws-eks-platform | cut -d' ' -f1,2)" platform/default.tfvars && echo key-match
```

Expect: the caller account equals `$ACCOUNT`; the bucket Region equals `region` in the backend file; versioning `Enabled`; encryption `AES256` or an approved KMS key; all four public-access-block settings `true`; `key-match` (your private key matches `ssh_public_key` in `platform/default.tfvars`). The VPC CIDR must not overlap laptop or connected networks. The state bucket is a prerequisite; do not create or import it from this root.

## 2. Deploy

```bash
mise run init
terraform -chdir=platform workspace show   # expect: default
mise run plan
```

Review the account, Region, AMI, instance type, and any replacement. The plan is saved only after `plan policy: PASS`; apply runs exactly that plan, and Terraform rejects it if state changed since.

```bash
mise run apply
mise run verify-live
```

Expect all live checks to pass; SSM registration can take a few minutes after first boot. Rollback is step 5; it cannot undo charges.

## 3. Verify SSM and SSH

The bastion has no public IP and no inbound rules; it reaches SSM over HTTPS through NAT. The access tasks read the target from the `connection` output, refuse a caller in another account, and require SSM `Online`.

```bash
mise run bastion
```

Inside the session: `cloud-init status --wait`, `systemctl is-active sshd amazon-ssm-agent`, and `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. Exit, then:

```bash
mise run ssh
```

Accept the first host key only if its fingerprint matches the one from the SSM session. A changed key after replacement needs a fresh SSM check.

A user-data change, such as a new SSH key, replaces the bastion. A newer AMI does not; to adopt it, replace deliberately: `mise run plan -- -replace=module.bastion.aws_instance.bastion`, then `mise run apply`.

## 4. Verify the tunnel

Set `PRIVATE_IP` and `PRIVATE_DNS` from `terraform -chdir=platform output -json connection` and record `getent ahostsv4 "$PRIVATE_DNS"`. In a second terminal:

```bash
mise run vpn
```

The tunnel routes only the VPC CIDR and forwards ordinary DNS (not DNS-over-HTTPS) through the bastion; it uses local sudo. In an SSM session, start a probe bound to the private IP:

```bash
PROBE_DIR=$(mktemp -d)
python3 -m http.server 8765 --bind "<private_ip>" --directory "$PROBE_DIR"
```

From a third terminal:

```bash
curl --noproxy '*' --fail -s -o /dev/null -w '%{http_code}\n' --max-time 10 "http://$PRIVATE_IP:8765"
getent ahostsv4 "$PRIVATE_DNS"
```

Expect `200` and the private address. Press Ctrl+C in the `vpn` terminal; the same curl must now fail and DNS must match the pre-tunnel result. Stop the probe and `rmdir "$PROBE_DIR"`. If the tunnel was killed abnormally, inspect local sshuttle and firewall state.

## 5. Tear down

End sessions and the tunnel. Destroy deletes the flow-log group and its retained logs; the state bucket remains.

```bash
mise run plan -- -destroy
```

Inspect the proposal and stop if it includes an unexpected target. The next command deletes without a prompt.

```bash
mise run apply
```

Expect `Apply complete!` with every planned resource destroyed. On partial failure, reconcile against Terraform state and plan again; do not delete resources or state by hand.

## If a step fails

Stop at the first mismatch: account, bucket Region, workspace, key fingerprint, host key, or plan. For connection failures, check in order: `connection` output, SSM `Online`, cloud-init, services, NAT egress, memory. Do not widen the security group or resize the instance without a reviewed decision.
