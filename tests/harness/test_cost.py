"""The cost cache check, offline: it compares fingerprints and never calls Infracost."""

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_check_fails_once_a_price_line_changes(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "docs").mkdir()
    shutil.copy(ROOT / "scripts/cost.sh", tmp_path / "scripts")
    shutil.copytree(ROOT / "platform", tmp_path / "platform", ignore=shutil.ignore_patterns(".terraform"))
    cost = ["bash", tmp_path / "scripts/cost.sh"]
    fingerprint = subprocess.run([*cost, "--print-fingerprint"], capture_output=True, text=True).stdout.strip()
    (tmp_path / "docs/cost.md").write_text(f"- Fingerprint: {fingerprint}\n")
    # Infracost is not on this PATH, so a call would fail the check.
    env = {"PATH": "/usr/bin:/bin"}
    assert subprocess.run([*cost, "--check"], env=env).returncode == 0

    tfvars = tmp_path / "platform/default.tfvars"
    tfvars.write_text(tfvars.read_text().replace('"t4g.medium"', '"t4g.large"'))
    result = subprocess.run([*cost, "--check"], env=env, capture_output=True, text=True)
    assert result.returncode == 1 and "stale" in result.stderr
