"""Required checks, run against fake tools: no cloud access or real scanners."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ("terraform", "tflint", "trivy", "uv", "aws", "kubectl", "infracost", "mise")


@pytest.fixture
def run_checks(tmp_path):
    for directory in ("scripts", "platform", "gitops", "bin"):
        (tmp_path / directory).mkdir()
    shutil.copy(ROOT / "scripts/checks.sh", tmp_path / "scripts")
    for tool in TOOLS:
        fake = tmp_path / "bin" / tool
        fake.write_text(f'#!/usr/bin/env bash\necho "{tool} $* | ${{TF_DATA_DIR:-}} | $PWD" >> "$CALLS"\n'
                        f'[[ "$FAIL" != {tool} ]]\n')
        fake.chmod(0o755)

    def run(fail=""):
        calls = tmp_path / "calls"
        calls.unlink(missing_ok=True)
        env = dict(os.environ, PATH=f"{tmp_path / 'bin'}:{os.environ['PATH']}", CALLS=str(calls),
                   FAIL=fail, TF_PLUGIN_CACHE_DIR=str(tmp_path / "plugins"))
        result = subprocess.run(["bash", tmp_path / "scripts/checks.sh"], env=env, cwd="/",
                                capture_output=True, text=True)
        return result, [line.split(" | ") for line in calls.read_text().splitlines()]

    return tmp_path, run


def test_runs_every_gate_offline_with_isolated_terraform_metadata(run_checks):
    root, run = run_checks
    result, calls = run()
    assert result.returncode == 0, result.stderr
    commands = [command for command, _, _ in calls]
    assert {cwd for _, _, cwd in calls} == {str(root)}
    for expected in ("uv run --locked --no-sync --no-env-file pytest",
                     "terraform -chdir=platform init -backend=false -input=false -no-color",
                     "terraform -chdir=platform validate -no-color",
                     "trivy config --exit-code 1 --tf-vars platform/default.tfvars platform/",
                     "trivy config --exit-code 1 gitops/",
                     "trivy fs --scanners secret --exit-code 1 ."):
        assert expected in commands
    assert any(c.startswith("tflint ") for c in commands)
    assert not any(c.split()[0] in {"aws", "kubectl", "infracost", "mise"} for c in commands)
    assert not any(word in c.split() for c in commands for word in ("plan", "apply", "destroy"))

    data_dirs = {data_dir for command, data_dir, _ in calls if command.startswith(("terraform", "tflint"))}
    assert len(data_dirs) == 1
    data_dir = Path(data_dirs.pop())
    assert data_dir.is_absolute() and root / "platform" not in data_dir.parents
    assert not data_dir.exists()


@pytest.mark.parametrize("tool", ["uv", "terraform", "tflint", "trivy"])
def test_any_failing_gate_fails_the_run(run_checks, tool):
    _, run = run_checks
    result, calls = run(fail=tool)
    assert result.returncode != 0
    assert calls[-1][0].startswith(tool)
