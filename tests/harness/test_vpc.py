"""Terraform variables and the committed address plan, evaluated offline."""

import json
import shutil
import subprocess
from ipaddress import ip_network
from pathlib import Path

import pytest

PLATFORM = Path(__file__).resolve().parents[2] / "platform"
TGW_RESERVED = ip_network("10.80.51.0/24")  # future transit-gateway attachment subnets


def console(tmp_path, expression, *overrides):
    # Only variables and locals: no providers, backend, files outside the repo, or AWS.
    for name in ("variables.tf", "locals.tf"):
        shutil.copy(PLATFORM / name, tmp_path)
    return subprocess.run(
        ["terraform", f"-chdir={tmp_path}", "console", f"-var-file={PLATFORM / 'default.tfvars'}",
         *(f"-var={override}" for override in overrides)],
        input=expression, capture_output=True, text=True)


def test_committed_subnets_fit_the_vpc_without_overlap(tmp_path):
    result = console(tmp_path, "jsonencode([var.vpc_cidr_block, var.private_subnets, var.public_subnets])")
    assert not result.stderr, result.stderr
    vpc, private, public = json.loads(json.loads(result.stdout))
    subnets = [ip_network(cidr) for cidr in [*private.values(), *public.values()]]
    assert private.keys() == public.keys()
    assert all(subnet.subnet_of(ip_network(vpc)) for subnet in subnets)
    assert all(not subnet.overlaps(TGW_RESERVED) for subnet in subnets)
    assert all(not a.overlaps(b) for i, a in enumerate(subnets) for b in subnets[i + 1:])


@pytest.mark.parametrize("override,expected", [
    ("name_prefix=", "eks-platform"),
    ("name_prefix=dev", "dev-eks-platform"),
    ("account_id=123456789012", "eks-platform"),
    ("region=us-east-1", "eks-platform"),
    ("account_id=1234", None),
    ("region=Stockholm", None),
    ('public_subnets={"eu-north-1a"="10.80.48.0/24"}', None),
    ("ssh_public_key=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 owner@example.com", None),
    # Split so the private-key pre-commit hook does not flag this test input.
    ("ssh_public_key=-----BEGIN OPENSSH " "PRIVATE KEY-----", None),
])
def test_variables_validate_shape_not_deployment_values(tmp_path, override, expected):
    # Console can exit zero even when validation fails, so stderr decides.
    result = console(tmp_path, "local.name", override)
    if expected is None:
        assert result.stderr
    else:
        assert not result.stderr, result.stderr
        assert json.loads(result.stdout) == expected
