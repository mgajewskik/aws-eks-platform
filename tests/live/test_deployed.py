"""The deployment matches the code and behaves as designed.

The plan policy already proved the configuration. These cases cover what it
cannot see: changes made outside Terraform and runtime behavior.
"""

import json
import time

import pytest


@pytest.fixture(scope="module")
def bastion(aws, terraform):
    instance_id = json.loads(terraform("output", "-json", "connection").stdout)["instance_id"]
    return aws("ec2", "describe-instances", "--instance-ids", instance_id)["Reservations"][0]["Instances"][0]


def test_live_state_matches_the_code(aws, terraform):
    # -lock=false keeps this read-only; exit code 2 means drift or unapplied changes.
    result = terraform("plan", "-var-file=default.tfvars", "-input=false", "-lock=false", "-detailed-exitcode",
                       "-no-color", check=False)
    assert result.returncode == 0, result.stdout[-4000:]


def test_bastion_is_reachable_only_through_ssm(aws, bastion):
    assert bastion["State"]["Name"] == "running"
    assert "PublicIpAddress" not in bastion
    # Rules added as separate resources outside Terraform do not show up as drift.
    groups = aws("ec2", "describe-security-groups", "--group-ids", *[g["GroupId"] for g in bastion["SecurityGroups"]])
    assert [group["IpPermissions"] for group in groups["SecurityGroups"]] == [[]]
    # SSM registers a few minutes after first boot, once cloud-init has egress through NAT.
    for _ in range(20):
        info = aws("ssm", "describe-instance-information", "--filters", f"Key=InstanceIds,Values={bastion['InstanceId']}")
        status = [instance["PingStatus"] for instance in info["InstanceInformationList"]]
        if status == ["Online"]:
            break
        time.sleep(15)
    assert status == ["Online"]


def test_vpc_flow_logs_are_delivered(aws, bastion):
    logs = aws("ec2", "describe-flow-logs", "--filter", f"Name=resource-id,Values={bastion['VpcId']}")["FlowLogs"]
    assert [(log["FlowLogStatus"], log["DeliverLogsStatus"]) for log in logs] == [("ACTIVE", "SUCCESS")]
