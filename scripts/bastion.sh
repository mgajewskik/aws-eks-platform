#!/usr/bin/env bash
# Owner-run SSM shell, SSH, or sshuttle tunnel to the deployed bastion.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "bastion: $*" >&2; exit 1; }
[[ $# -eq 1 && $1 =~ ^(ssm|ssh|vpn)$ ]] || { echo "usage: bastion.sh {ssm|ssh|vpn}" >&2; exit 2; }
mode=$1
key="$HOME/.ssh/aws-eks-platform"
for tool in terraform aws jq session-manager-plugin; do
  command -v "$tool" >/dev/null || fail "missing $tool; see the bastion runbook"
done
[[ $mode == ssm || -f $key ]] || fail "missing SSH key $key"

# The deployed state names the target; refuse credentials for any other account.
read -r account region cidr user instance < <(
  terraform -chdir=platform output -json connection |
    jq -r '[.account_id, .region, .vpc_cidr, .ssh_user, .instance_id] | select(all(type == "string" and . != "")) | @tsv'
) || fail "no deployed bastion in Terraform state; check your login and deployment"
caller=$(aws sts get-caller-identity --region "$region" --query Account --output text) || fail "AWS login failed"
[[ $caller == "$account" ]] || fail "AWS credentials must be for account $account"
status=$(aws ssm describe-instance-information --region "$region" --filters "Key=InstanceIds,Values=$instance" \
  --query 'InstanceInformationList[0].PingStatus' --output text)
[[ $status == Online ]] || fail "bastion $instance is not Online in SSM; check instance health and cloud-init"

[[ $mode == ssm ]] && exec aws ssm start-session --target "$instance" --region "$region"
proxy="aws ssm start-session --target $instance --document-name AWS-StartSSHSession --parameters portNumber=%p --region $region"
ssh=(ssh -o "ProxyCommand=$proxy" -o IdentitiesOnly=yes -o StrictHostKeyChecking=ask -i "$key")
[[ $mode == ssh ]] && exec "${ssh[@]}" "$user@$instance"
echo "Tunneling $cidr and DNS through $instance. Ctrl+C stops."
printf -v ssh_cmd "%q " "${ssh[@]}"
exec sshuttle --ssh-cmd "$ssh_cmd" --remote "$user@$instance" --dns --disable-ipv6 "$cidr"
