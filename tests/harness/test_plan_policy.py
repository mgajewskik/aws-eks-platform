"""The plan policy and the plan script that gates apply on it."""

import copy
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest
from plan_policy import violations

ROOT = Path(__file__).resolve().parents[2]
TAGS = {"Project": "eks-platform"}
BASTION = {
    "associate_public_ip_address": False,
    "metadata_options": [{"http_tokens": "required"}],
    "root_block_device": [{"encrypted": True}],
    "tags_all": TAGS,
}
GOOD = [
    ("module.bastion.aws_instance.bastion", "aws_instance", BASTION),
    ("aws_subnet.private", "aws_subnet", {"map_public_ip_on_launch": False, "tags_all": TAGS}),
    ("aws_security_group.bastion", "aws_security_group", {"ingress": [], "tags_all": TAGS}),
    ("aws_vpc_security_group_ingress_rule.vpc", "aws_vpc_security_group_ingress_rule",
     {"cidr_ipv4": "10.80.0.0/16", "tags_all": TAGS}),
    ("aws_cloudwatch_log_group.flow_logs", "aws_cloudwatch_log_group", {"retention_in_days": 7, "tags_all": TAGS}),
    ("aws_iam_role_policy_attachment.ssm", "aws_iam_role_policy_attachment",
     {"policy_arn": "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"}),
    ("aws_route.private_internet", "aws_route", {"destination_cidr_block": "0.0.0.0/0"}),
]


def plan(resources=GOOD, actions=("create",)):
    return {"resource_changes": [
        {"address": address, "mode": "managed", "type": kind,
         "change": {"actions": list(actions), "after": None if actions == ("delete",) else after,
                    "after_unknown": {}}}
        for address, kind, after in resources]}


def changed(index, **values):
    resources = copy.deepcopy(GOOD)
    resources[index][2].update(values)
    return resources


def test_compliant_plan_passes():
    assert violations(plan()) == []


@pytest.mark.parametrize("resources,problem", [
    (changed(0, associate_public_ip_address=True), "has a public IP"),
    (changed(0, metadata_options=[{"http_tokens": "optional"}]), "does not require IMDSv2"),
    (changed(0, metadata_options=[]), "does not require IMDSv2"),
    (changed(0, root_block_device=[{"encrypted": False}]), "has an unencrypted root volume"),
    (changed(1, map_public_ip_on_launch=True), "assigns public IPs"),
    (changed(2, ingress=[{"cidr_blocks": ["0.0.0.0/0"], "ipv6_cidr_blocks": []}]), "inbound traffic from the internet"),
    (changed(3, cidr_ipv4=None, cidr_ipv6="::/0"), "inbound traffic from the internet"),
    ([("aws_security_group_rule.web", "aws_security_group_rule",
       {"type": "ingress", "cidr_blocks": ["0.0.0.0/0"]})], "inbound traffic from the internet"),
    (changed(4, retention_in_days=0), "keeps logs forever"),
    (changed(5, policy_arn="arn:aws:iam::aws:policy/AdministratorAccess"), "grants administrator access"),
    (changed(1, tags_all={"Name": "private"}), "missing Project tag"),
])
def test_each_invariant_is_enforced(resources, problem):
    found = violations(plan(resources))
    assert len(found) == 1 and problem in found[0], found


@pytest.mark.parametrize("actions,rejected", [
    (("delete",), True),
    (("delete", "create"), True),
    (("create", "delete"), True),
    (("update",), False),
])
def test_protected_resources_are_never_deleted_or_replaced(actions, rejected):
    bucket = [("aws_s3_bucket.state", "aws_s3_bucket", {"tags_all": TAGS})]
    assert bool(violations(plan(bucket, actions))) == rejected


def test_destroy_plan_of_disposable_resources_passes():
    assert violations(plan(actions=("delete",))) == []


def test_unknown_tags_are_not_judged_before_apply():
    unknown = plan(changed(1, tags_all=None))
    unknown["resource_changes"][1]["change"]["after_unknown"] = {"tags_all": True}
    assert violations(unknown) == []


@pytest.fixture
def run_plan(tmp_path):
    (tmp_path / "scripts").mkdir()
    for name in ("plan.sh", "plan_policy.py"):
        shutil.copy(ROOT / "scripts" / name, tmp_path / "scripts")
    (tmp_path / "platform").mkdir()
    fake = tmp_path / "bin/terraform"
    fake.parent.mkdir()
    fake.write_text('#!/usr/bin/env bash\necho "terraform $*" >> "$CALLS"\n'
                    'for arg; do [[ $arg == -out=* ]] && echo plan > "${arg#-out=}"; done\n'
                    '[[ $2 == show ]] && echo "$PLAN_JSON"\nexit 0\n')
    fake.chmod(0o755)

    def run(planned, *args):
        env = dict(os.environ, PATH=f"{fake.parent}:{os.environ['PATH']}", CALLS=str(tmp_path / "calls"),
                   PLAN_JSON=json.dumps(planned))
        result = subprocess.run(["bash", tmp_path / "scripts/plan.sh", *args], env=env,
                                capture_output=True, text=True)
        return result, (tmp_path / "calls").read_text().splitlines(), tmp_path / "platform/tfplan"

    return run


def test_verified_plan_is_saved_for_apply(run_plan):
    result, calls, saved = run_plan(plan(), "-destroy")
    assert result.returncode == 0, result.stderr
    assert saved.read_text() == "plan\n" and saved.stat().st_mode & 0o077 == 0
    assert calls[0].startswith("terraform -chdir=platform plan -var-file=default.tfvars -input=false -out=")
    assert calls[0].endswith(" -destroy")


def test_rejected_plan_leaves_nothing_to_apply(run_plan):
    run_plan(plan())
    result, _, saved = run_plan(plan(changed(0, associate_public_ip_address=True)))
    assert result.returncode != 0 and "has a public IP" in result.stderr
    assert not saved.exists()
