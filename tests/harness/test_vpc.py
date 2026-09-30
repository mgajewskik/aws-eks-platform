"""Check the committed address allocation without cloud credentials."""

from ipaddress import ip_network
from pathlib import Path
import re
import json
import shutil
import subprocess

import pytest


TFVARS = Path(__file__).resolve().parents[2] / "platform/default.tfvars"


def _subnets(text, name):
    block = re.search(rf"(?ms)^{name}\s*=\s*\{{(.*?)^\}}", text)
    assert block is not None, f"missing {name} allocation"
    return {
        az: ip_network(cidr)
        for az, cidr in re.findall(r'(eu-north-1[abc])\s*=\s*"([^"]+)"', block.group(1))
    }


def test_accepted_three_az_subnets_are_disjoint_and_inside_vpc():
    text = TFVARS.read_text()
    vpc = ip_network(re.search(r'vpc_cidr_block\s*=\s*"([^"]+)"', text).group(1))
    private = _subnets(text, "private_subnets")
    public = _subnets(text, "public_subnets")

    assert vpc == ip_network("10.80.0.0/16")
    assert set(private) == set(public) == {"eu-north-1a", "eu-north-1b", "eu-north-1c"}
    all_subnets = list(private.values()) + list(public.values())
    assert len(all_subnets) == 6
    assert all(subnet.subnet_of(vpc) for subnet in all_subnets)
    assert all(not left.overlaps(right) for index, left in enumerate(all_subnets)
               for right in all_subnets[index + 1:])
    assert all(not subnet.overlaps(ip_network("10.80.51.0/24")) for subnet in all_subnets)


@pytest.mark.parametrize("prefix,expected", [("", "eks-platform"), ("dev", "dev-eks-platform")])
def test_real_tfvars_validate_and_prefix_evaluates_offline(tmp_path, prefix, expected):
    # Isolate pure input/locals evaluation: no providers, backend, keys, or AWS.
    for name in ("variables.tf", "locals.tf"):
        shutil.copyfile(TFVARS.parent / name, tmp_path / name)
    result = subprocess.run(
        ["terraform", f"-chdir={tmp_path}", "console", "-no-color",
         f"-var-file={TFVARS}", f"-var=name_prefix={prefix}"],
        input="local.name\n", text=True, capture_output=True,
    )
    # Console can return zero even when input validation reports an error.
    assert result.returncode == 0 and not result.stderr, result.stderr
    assert json.loads(result.stdout) == expected
