#!/usr/bin/env bash
# Owner-run SSM, SSH, and sshuttle access. No setup or deployment side effects.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf 'bastion: %s\n' "$*" >&2; exit 1; }
require() { command -v "$1" >/dev/null || fail "Missing $1. See the bastion runbook."; }
shell_join() { jq -nr --args '$ARGS.positional | @sh' -- "$@"; }

if [[ $# -ne 1 || ! "$1" =~ ^(ssm|ssh|vpn)$ ]]; then
  printf 'Usage: bash scripts/bastion.sh {ssm|ssh|vpn}\n' >&2
  exit 2
fi
mode="$1"
account_id="220263133738"
region="eu-north-1"
vpc_cidr="10.80.0.0/16"
identity="$HOME/.ssh/aws-eks-platform"
for tool in terraform aws jq session-manager-plugin; do require "$tool"; done
if [[ "$mode" != ssm ]]; then
  require ssh
  [[ -f "$identity" ]] || fail "Missing laptop SSH key: $identity"
fi
if [[ "$mode" == vpn ]]; then require sshuttle; fi

# Check credentials before reading remote state or selecting an instance.
caller_account=$(aws sts get-caller-identity --query Account --output text \
  --region "$region" --no-cli-pager) || fail "AWS identity check failed. Check your login."
[[ "$caller_account" == "$account_id" ]] || fail "AWS account must be $account_id."

connection=$(terraform -chdir=platform output -json connection) || \
  fail "Terraform connection output is unavailable. Deploy the platform first."
jq -e --arg account "$account_id" --arg region "$region" --arg cidr "$vpc_cidr" '
  .account_id == $account and .region == $region and .vpc_cidr == $cidr and
  .ssh_user == "ec2-user" and
  (.instance_id | type == "string" and test("^i-([0-9a-f]{8}|[0-9a-f]{17})$"))
' <<< "$connection" >/dev/null || fail "State has a missing or mismatched connection target."
instance_id=$(jq -r '.instance_id' <<< "$connection")

online_instance=$(aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$instance_id" \
  --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' \
  --output text --region "$region" --no-cli-pager) || fail "SSM readiness check failed."
[[ "$online_instance" == "$instance_id" ]] || fail "Bastion is not Online in SSM. Check instance health and cloud-init."

if [[ "$mode" == ssm ]]; then
  exec aws ssm start-session --target "$instance_id" --region "$region" --no-cli-pager
fi

proxy=(aws ssm start-session --target "$instance_id" --document-name AWS-StartSSHSession
  --parameters 'portNumber=%p' --region "$region" --no-cli-pager)
ssh_args=(ssh -o "ProxyCommand=$(shell_join "${proxy[@]}")" -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=ask -i "$identity")
remote="ec2-user@$instance_id"
if [[ "$mode" == ssh ]]; then
  exec "${ssh_args[@]}" "$remote"
fi

printf 'Tunneling %s and ordinary DNS through %s. Ctrl+C stops the tunnel.\n' "$vpc_cidr" "$instance_id"
exec sshuttle --ssh-cmd "$(shell_join "${ssh_args[@]}")" \
  --remote "$remote" --dns --disable-ipv6 "$vpc_cidr"
