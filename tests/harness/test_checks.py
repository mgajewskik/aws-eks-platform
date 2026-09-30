"""Exercise default check dispatch without cloud access or real external tools."""

import os
from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def check_repo(tmp_path):
    for directory in ("scripts", "platform", "tests", "bin"):
        (tmp_path / directory).mkdir()
    shutil.copyfile(ROOT / "scripts/checks.sh", tmp_path / "scripts/checks.sh")
    calls = tmp_path / "calls"
    env = dict(os.environ, PATH=f"{tmp_path / 'bin'}:{os.environ['PATH']}",
               HARNESS_CALLS=str(calls))
    for name in ("terraform", "tflint", "trivy", "uv", "aws", "kubectl", "infracost", "mise"):
        executable = tmp_path / "bin" / name
        executable.write_text(
            '#!/usr/bin/env bash\n'
            f'printf "%s\\n" "{name} $*" >> "$HARNESS_CALLS"\n'
            f'if [[ "${{FAIL_TOOL:-}}" == "{name}" ]]; then exit 17; fi\n'
        )
        executable.chmod(0o755)

    def run_checks(fail_tool=""):
        result = subprocess.run(
            ["bash", str(tmp_path / "scripts/checks.sh")], cwd="/tmp",
            env=dict(env, FAIL_TOOL=fail_tool), text=True, capture_output=True,
        )
        recorded = calls.read_text().splitlines() if calls.exists() else []
        return result, recorded

    return tmp_path, run_checks


def assert_no_live_commands(calls):
    for call in calls:
        assert call.split()[0] not in {"aws", "kubectl", "infracost", "mise"}
        assert not call.startswith(("terraform apply", "terraform destroy", "terraform plan"))


def test_empty_platform_runs_harness_and_security_checks(check_repo):
    _, run_checks = check_repo
    result, calls = run_checks()
    assert result.returncode == 0, result.stderr
    assert "uv run --locked --no-sync --no-env-file pytest" in calls
    assert any(call.startswith("trivy config ") and call.endswith("platform/") for call in calls)
    assert any(call.startswith("trivy fs ") and "--scanners secret" in call for call in calls)
    assert not any(call.startswith(("terraform init", "terraform validate", "tflint")) for call in calls)
    assert_no_live_commands(calls)


def test_configuration_enables_validation_and_gitops_scan(check_repo):
    root, run_checks = check_repo
    (root / "platform/main.tf").write_text('terraform {}\n')
    (root / "platform/default.tfvars").write_text('name_prefix = ""\n')
    (root / "gitops").mkdir()
    (root / "gitops/app.yaml").write_text('apiVersion: v1\nkind: Namespace\n')
    result, calls = run_checks()
    assert result.returncode == 0, result.stderr
    assert "terraform init -backend=false -input=false -no-color" in calls
    assert "terraform validate -no-color" in calls
    assert "trivy config --exit-code 1 --tf-vars platform/default.tfvars platform/" in calls
    assert any(call.startswith("tflint ") for call in calls)
    assert any(call.startswith("trivy config ") and call.endswith("gitops/") for call in calls)
    assert_no_live_commands(calls)


def test_failed_harness_tests_stop_before_other_tools(check_repo):
    _, run_checks = check_repo
    result, calls = run_checks(fail_tool="uv")
    assert result.returncode != 0
    assert len(calls) == 1


def test_scanner_failure_is_not_a_pass(check_repo):
    _, run_checks = check_repo
    result, calls = run_checks(fail_tool="trivy")
    assert result.returncode != 0
    assert_no_live_commands(calls)
