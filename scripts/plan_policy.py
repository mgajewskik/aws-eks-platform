"""Reject a Terraform plan whose resolved values break the platform's invariants.

Trivy scans the source. This checks the plan, where variables and module inputs
are resolved and inline scanner ignores do not apply.
"""

import json
import sys
from pathlib import Path

# Retained data and shared resources; the disposable root must never delete or replace them.
# A disposable key, such as one for EKS secrets, needs an address-based exception when it arrives.
PROTECTED = {"aws_s3_bucket", "aws_route53_zone", "aws_secretsmanager_secret",
             "aws_ecr_repository", "aws_kms_key", "aws_dynamodb_table"}
ADMIN_POLICIES = {f"arn:aws:iam::aws:policy/{name}"
                  for name in ("AdministratorAccess", "PowerUserAccess", "IAMFullAccess")}
INTERNET = {"0.0.0.0/0", "::/0"}


def ingress_cidrs(kind, after):
    if kind in ("aws_security_group", "aws_default_security_group"):
        rules = after.get("ingress") or []
    elif kind == "aws_security_group_rule" and after.get("type") == "ingress":
        rules = [after]
    elif kind == "aws_vpc_security_group_ingress_rule":
        return [after.get("cidr_ipv4"), after.get("cidr_ipv6")]
    else:
        return []
    return [cidr for rule in rules for cidr in (rule.get("cidr_blocks") or []) + (rule.get("ipv6_cidr_blocks") or [])]


def problems(kind, after, unknown):
    # Cost Explorer and the cost-audit bill filter by this tag, so every taggable resource needs it.
    if "tags_all" in after and not unknown.get("tags_all") and "Project" not in (after["tags_all"] or {}):
        yield "missing Project tag"
    if INTERNET & set(ingress_cidrs(kind, after)):
        yield "allows inbound traffic from the internet"
    if kind == "aws_instance":
        if after.get("associate_public_ip_address"):
            yield "has a public IP"
        if not all(options.get("http_tokens") == "required" for options in after.get("metadata_options") or [{}]):
            yield "does not require IMDSv2"
        if not all(device.get("encrypted") for device in after.get("root_block_device") or [{}]):
            yield "has an unencrypted root volume"
    if kind == "aws_subnet" and after.get("map_public_ip_on_launch"):
        yield "assigns public IPs"
    if kind == "aws_cloudwatch_log_group" and not after.get("retention_in_days"):
        yield "keeps logs forever"
    if after.get("policy_arn") in ADMIN_POLICIES:
        yield "grants administrator access"


def violations(plan):
    found = []
    for resource in plan.get("resource_changes", []):
        if resource["mode"] != "managed":
            continue
        address, kind, change = resource["address"], resource["type"], resource["change"]
        if kind in PROTECTED and "delete" in change["actions"]:
            found.append(f"{address}: deletes or replaces protected {kind}")
        if change["after"] is not None:
            found += [f"{address}: {problem}"
                      for problem in problems(kind, change["after"], change["after_unknown"] or {})]
    return found


if __name__ == "__main__":
    found = violations(json.loads(Path(sys.argv[1]).read_text()))
    for line in found:
        print(f"plan policy: {line}", file=sys.stderr)
    print(f"plan policy: {'FAIL' if found else 'PASS'}")
    sys.exit(1 if found else 0)
