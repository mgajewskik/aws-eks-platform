"""Bastion access targets the deployed state, using fake terraform and aws."""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
STATE = {"account_id": "123456789012", "region": "eu-west-3", "vpc_cidr": "10.1.0.0/16",
         "ssh_user": "ec2-user", "instance_id": "i-0123456789abcdef0"}
FAKES = {
    "terraform": 'echo "$STATE"',
    "aws": 'case "$1 $2" in "sts get-caller-identity") echo "$CALLER" ;; "ssm describe-instance-information") echo Online ;; esac',
    "session-manager-plugin": "",
}


@pytest.fixture
def run_bastion(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "bin").mkdir()
    shutil.copy(ROOT / "scripts/bastion.sh", tmp_path / "scripts")
    for name, body in FAKES.items():
        fake = tmp_path / "bin" / name
        fake.write_text(f'#!/usr/bin/env bash\necho "{name} $*" >> "$CALLS"\n{body}\n')
        fake.chmod(0o755)

    def run(state=STATE, caller=STATE["account_id"]):
        calls = tmp_path / "calls"
        env = dict(os.environ, PATH=f"{tmp_path / 'bin'}:{os.environ['PATH']}", CALLS=str(calls),
                   STATE=json.dumps(state), CALLER=caller)
        result = subprocess.run(["bash", tmp_path / "scripts/bastion.sh", "ssm"], env=env,
                                capture_output=True, text=True)
        return result, calls.read_text().splitlines() if calls.exists() else []

    return run


def test_session_targets_the_state_account_and_region(run_bastion):
    result, calls = run_bastion()
    assert result.returncode == 0, result.stderr
    assert calls[-1] == "aws ssm start-session --target i-0123456789abcdef0 --region eu-west-3"


def test_caller_in_another_account_is_refused(run_bastion):
    result, calls = run_bastion(caller="999999999999")
    assert result.returncode != 0 and "123456789012" in result.stderr
    assert not any(call.startswith("aws ssm") for call in calls)


@pytest.mark.parametrize("field,value", [("instance_id", None), ("ssh_user", "")])
def test_incomplete_target_is_refused_before_aws_calls(run_bastion, field, value):
    result, calls = run_bastion(state={**STATE, field: value})
    assert result.returncode != 0
    assert not any(call.startswith("aws") for call in calls)
