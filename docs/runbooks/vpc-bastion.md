# Deploy and connect to the VPC bastion

## Info

| ID | Outcome | Tools | Permissions | Author | Updated | Escalation |
|---|---|---|---|---|---|---|
| VPC-BASTION | Owner can deploy the VPC, verify SSM/SSH and a VPC-only tunnel, then remove disposable resources | Pinned Terraform, AWS CLI, uv, ssh, sshuttle, Session Manager plugin | Account `220263133738`; S3 state access, Terraform resource permissions, and SSM session/describe permissions | Platform owner | 2026-09-30 | Stop on a mismatched account, bucket, plan, or live target |

This is an **owner-run** procedure from the repository root on the owner's Linux x86_64 laptop. Agents and CI do not initialize this backend, plan, apply, destroy, or start sessions. Nothing in this repository has been deployed. The foundation creates a VPC (`10.80.0.0/16`) in `eu-north-1` and one private AL2023 `t4g.medium` bastion. It does not create EKS or application DNS. The existing S3 state bucket is retained after platform teardown. See [cost assumptions](../cost.md) before leaving resources running.

Every command below is **owner-run only**. The AWS identity, bucket, SSH fingerprint, and post-deletion checks are read-only and need no rollback. Local setup downloads tools and writes ignored files; delete those files to reverse it. `init` writes local Terraform metadata, while `plan` may write and release an S3 lock object without changing infrastructure. `apply` and `destroy` use `-auto-approve` and change billable cloud resources without a confirmation prompt. Review a separate plan before invoking either command, and use the teardown procedure for resources that Terraform created. Sessions and the private listener are temporary; `exit` and Ctrl+C close them. The VPN also changes local firewall interception while active; Ctrl+C is its normal rollback. Each step below states its expected signal and failure stop.

## 1. Check the target and prepare local tools

Use the existing AWS credential chain. The caller account must be `220263133738`; the Terraform provider and connection script also reject another account. The owner confirmed the state bucket's Region as `eu-west-1`, which is recorded in the backend file and differs from the platform Region `eu-north-1`. Verify that AWS reports `eu-west-1` during preflight; agents have not checked the live bucket. Require bucket versioning `Enabled`, server-side encryption (`AES256` or the owner's approved KMS key), and all four public-access-block settings `true`; stop if any check differs. The backend requires state-object access and read/write/delete access to the adjacent `.tflock` object. Do not create or import the bucket from this root.

If the pinned local tools are not installed, prepare them first. This writes local tool caches and downloads packages, without changing AWS resources:

```bash
rtk proxy mise install aws jq python uv terraform
```

```bash
rtk proxy mise exec -- aws sts get-caller-identity --region eu-north-1 --query Account --output text
rtk proxy mise exec -- aws s3api get-bucket-location --bucket terraform-state-220263133738 --expected-bucket-owner 220263133738 --query LocationConstraint --output text
rtk proxy mise exec -- aws s3api get-bucket-encryption --bucket terraform-state-220263133738 --expected-bucket-owner 220263133738
rtk proxy mise exec -- aws s3api get-bucket-versioning --bucket terraform-state-220263133738 --expected-bucket-owner 220263133738
rtk proxy mise exec -- aws s3api get-public-access-block --bucket terraform-state-220263133738 --expected-bucket-owner 220263133738
rtk proxy ssh-keygen -lf ~/.ssh/aws-eks-platform.pub
```

The expected account output is `220263133738`, and the bucket Region must be `eu-west-1`; stop on a mismatch. The public key should parse, and its private counterpart must stay at `~/.ssh/aws-eks-platform` on the laptop. Confirm `10.80.0.0/16` does not overlap laptop or connected networks. `platform/default.tfvars` contains non-secret account, platform Region, CIDR, and public-key path values. The backend file contains bucket, bucket Region, state key, encryption, and locking settings, not Terraform input variables. Use the default Terraform workspace only; `name_prefix` changes resource names, not the backend key.

Prepare the locked Python environment if needed. The access tasks require an externally managed `session-manager-plugin` executable on `PATH`; this repository does not install or pin the plugin.

```bash
rtk proxy mise exec -- uv sync --locked --no-python-downloads
```

Python setup writes local caches and `.venv/`; downloads contact package hosts, not AWS account APIs. Successful setup exits with code zero. The owner can delete those ignored local directories to reverse setup; this does not reverse downloaded data transfer. The access tasks require the AWS CLI, `jq`, Session Manager plugin, `ssh`, and the laptop key. `sshuttle` is a normal locked uv dependency. Do not put credentials or the private key into tfvars, state, logs, or Git.

## 2. Initialize, review, and deploy

Run `terraform -chdir=platform init -reconfigure -backend-config=backend.s3.hcl` after the preflight in step 1. Backend settings come from `platform/backend.s3.hcl`; init uses `-reconfigure` and does not run a separate bucket lookup. No separate `BACKEND_REGION` assignment is needed. Terraform's `-chdir=platform` makes the backend file and tfvars paths relative to `platform/`.

```bash
rtk proxy mise exec -- terraform -chdir=platform init -reconfigure -backend-config=backend.s3.hcl
rtk proxy mise exec -- terraform -chdir=platform workspace show
rtk proxy mise exec -- terraform -chdir=platform plan -var-file=default.tfvars
```

Inspect the proposal before running the next commands. Apply has no confirmation prompt:

```bash
rtk proxy mise exec -- terraform -chdir=platform apply -var-file=default.tfvars -auto-approve
rtk proxy mise exec -- terraform -chdir=platform output -json connection
```

Expect `Terraform has been successfully initialized!`. Reuse `terraform -chdir=platform init -reconfigure -backend-config=backend.s3.hcl` after configuration changes or in a fresh checkout; initialization is already repeatable, and `-reconfigure` reloads backend settings without migrating state. Stop on an account, bucket, Region, or backend error; this flag does not move state if the backend target changes. Init writes local metadata and may download providers/modules, without deploying resources. Local metadata can be regenerated by running the same task; it does not delete remote state. Check the selected backend and workspace before continuing.

`workspace show` must say `default`. Review the account, Region, resolved AL2023 AMI, `t4g.medium`, resource changes, and any replacement before applying. `terraform -chdir=platform plan -var-file=default.tfvars` reads AWS with `default.tfvars`, displays its proposal in the terminal without saving a plan file, and may briefly create a remote S3 lock object. Stop after this command to inspect the proposal before invoking `terraform -chdir=platform apply -var-file=default.tfvars -auto-approve`. Apply uses the same tfvars to generate and apply a fresh plan with `-auto-approve`, without a confirmation prompt. It can differ from the earlier proposal if configuration or remote state changed, and there is no prompt at which to inspect and approve that fresh plan. Neither command saves or requires a plan file. Plan, apply, and destroy do not initialize the backend or run each other. Apply's rollback is the owner-run destroy in step 5, which cannot undo charges or recover deleted logs. The `connection` output should contain the exact bastion instance ID, private IP and DNS name, VPC CIDR, account, and Region. Save the instance ID for teardown verification. No successful local check proves these live outcomes.

## 3. Prove SSM and SSH readiness

The instance has no public IP or inbound security-group rule. It reaches SSM endpoints over outbound HTTPS through regional NAT. The operator needs permission to describe SSM managed nodes and start/close sessions. The bastion role supplies only its managed-node permissions. Connection tasks select the instance from Terraform's `connection` output, verify account/Region/CIDR, and require SSM `Online` before starting a session. An AMI or cloud-init change replaces this one bastion and interrupts access.

```bash
rtk proxy mise run bastion
```

Inside the SSM shell, run `cloud-init status --wait`, `systemctl is-active sshd amazon-ssm-agent`, and `free -m`. Expect completed cloud-init, both services active, and enough free memory for one session on the `t4g.medium`. Inspect local system logs for OOM kills if the session or tunnel fails. Exit the SSM shell before the SSH check.

```bash
rtk proxy mise run ssh
```

Before accepting SSH's first host-key prompt, compare its SHA256 fingerprint with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` run inside the trusted SSM shell on that same instance. A mismatch means stop; do not accept the key. Successful SSH should enter `ec2-user` using the laptop private key over SSM. Session termination or `exit` closes the connection. An unexpected host-key change after replacement requires a fresh SSM fingerprint check.

## 4. Prove the tunnel and clean stop

Read the `private_ip` and `private_dns` fields from the `connection` output in step 2. Set `PRIVATE_IP` and `PRIVATE_DNS` to those values in the laptop terminal used for probes. Record its current ordinary DNS lookup for that private name, then start the tunnel in a separate terminal:

```bash
PRIVATE_IP='<private_ip from connection>'
PRIVATE_DNS='<private_dns from connection>'
rtk proxy getent ahostsv4 "$PRIVATE_DNS"
```

In a separate laptop terminal, start the tunnel:

```bash
rtk proxy mise run vpn
```

`vpn` starts local `sshuttle` with sudo. It routes **application traffic only for `10.80.0.0/16`** through SSH over SSM and temporarily forwards ordinary laptop DNS queries with `--dns`; unrelated application networks keep their normal route. Browser DNS-over-HTTPS and other encrypted/custom resolvers are outside `--dns`. The terminal should report the VPC CIDR and selected instance; leave it running for the next probes.

In an SSM shell, start a temporary HTTP probe bound to the bastion's `private_ip` from the Terraform output. Set `PRIVATE_IP` in that remote shell too. It serves only an empty temporary directory, stays active until Ctrl+C, and the bastion security group remains without inbound rules.

```bash
rtk proxy mise run bastion
```

Then, inside that SSM shell, run:

```bash
PRIVATE_IP='<private_ip from connection>'
PROBE_DIR=$(mktemp -d)
python3 -m http.server 8765 --bind "$PRIVATE_IP" --directory "$PROBE_DIR"
```

From a third laptop terminal while the tunnel runs, use the matching values from `connection`:

```bash
rtk proxy curl --noproxy '*' --fail --silent --show-error --output /dev/null --write-out '%{http_code}\n' --max-time 10 "http://$PRIVATE_IP:8765"
rtk proxy getent ahostsv4 "$PRIVATE_DNS"
```

Expect HTTP `200` from the private TCP listener and the private name to resolve to its expected private address. This proves the laptop-to-bastion path only, not future EKS or cross-subnet reachability. If DNS differs, inspect the laptop resolver and any browser DoH setting before claiming DNS works.

Press **Ctrl+C** in the `vpn` terminal. Repeat `rtk proxy getent ahostsv4 "$PRIVATE_DNS"` and compare with the pre-tunnel result; `rtk proxy curl --noproxy '*' --max-time 10 "http://$PRIVATE_IP:8765"` should now fail while the remote listener still runs. A normal stop should remove sshuttle's temporary local routing/DNS interception. Then press Ctrl+C on the remote listener, run `rmdir "$PROBE_DIR"` in the SSM shell, and exit. If the VPN process is killed abnormally, inspect local sshuttle/firewall state before assuming cleanup. SSM/SSH sessions and the tunnel are temporary local/remote session changes; `exit` or Ctrl+C is their normal rollback.

## 5. Tear down and verify

Only the owner decides when to remove the disposable VPC. End the tunnel and sessions first, then review Terraform's destroy proposal. Destroy deletes the VPC Flow Logs group, including its seven days of retained diagnostic data; the S3 state bucket and state object remain. Record the bastion instance ID and log-group name before deletion.

```bash
rtk proxy mise exec -- terraform -chdir=platform plan -destroy -var-file=default.tfvars
```

Inspect the destroy proposal and stop if it includes an unexpected target. The next command immediately deletes resources without a confirmation prompt; its fresh proposal can differ if configuration or state changed:

```bash
rtk proxy mise exec -- terraform -chdir=platform destroy -var-file=default.tfvars -auto-approve
rtk proxy mise exec -- terraform -chdir=platform state list
rtk proxy mise exec -- aws logs describe-log-groups --region eu-north-1 --log-group-name-prefix /aws/vpc/eks-platform-flow-logs --query "logGroups[?logGroupName=='/aws/vpc/eks-platform-flow-logs'].logGroupName"
```

`terraform -chdir=platform destroy -var-file=default.tfvars -auto-approve` uses `default.tfvars` and `-auto-approve` to delete resources without interactive approval. Expect Terraform to show an empty managed-resource list and the exact flow-log group to be absent. If `name_prefix` was set, use its resulting log-group name in the AWS read. Check the recorded instance in EC2 and the VPC/NAT in the AWS console if destroy reports partial failure. Destroy is a high-impact, irreversible cloud mutation: it stops billing for removed resources but cannot recover deleted logs or undo charges. Resolve any partial failure against Terraform state before another apply; do not delete resources or state by hand.

## If a step fails

Stop at the first mismatched account, backend Region, workspace, public-key fingerprint, SSH host-key fingerprint, or Terraform plan. For connection failure, use `connection` to confirm the instance target, then check SSM `Online`, cloud-init completion, service health, NAT egress, and available memory in that order. A green offline `mise run checks` does not establish live access. Do not widen the security group or change the instance size without an explicit reviewed decision.
