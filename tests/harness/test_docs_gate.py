"""Behavioral checks for the Feature-close documentation gate."""

import shutil
import subprocess
from pathlib import Path

import pytest


SOURCE_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "docs-gate.sh"
SOURCE_CHECKER = SOURCE_SCRIPT.with_name("docs_gate.py")
ITEMS = {
    "Plan": "- [x] Plan: evidence: docs/plans/feature.md | Progress and Outcomes record completion",
    "Architecture": "- [x] Architecture: evidence: README.md | Architecture summary updated",
    "Runbook": "- [ ] Runbook: skip: No operator procedure changed",
    "ADR": "- [ ] ADR: skip: No durable architecture choice made",
    "Glossary": "- [ ] Glossary: skip: No domain term resolved",
    "README": "- [x] README: evidence: README.md | Public setup steps updated",
}


@pytest.fixture
def run_gate(tmp_path):
    root = tmp_path / "repo"
    (root / "scripts").mkdir(parents=True)
    (root / "docs" / "plans").mkdir(parents=True)
    shutil.copy2(SOURCE_SCRIPT, root / "scripts" / "docs-gate.sh")
    shutil.copy2(SOURCE_CHECKER, root / "scripts" / "docs_gate.py")
    plan = root / "docs" / "plans" / "feature.md"
    (root / "README.md").write_text("# Project\n")
    (tmp_path / "outside.md").write_text("# Outside\n")
    (root / "linked.md").symlink_to(tmp_path / "outside.md")

    def invoke(items=None, cwd=None, progress="Implemented and validated.", outcomes="The docs gate is verified."):
        checklist = "\n".join((items if items is not None else ITEMS).values())
        plan.write_text(
            "# Feature\n\n## Docs gate\n\n"
            + checklist
            + f"\n\n## Progress\n\n{progress}\n"
            + f"\n## Outcomes\n\n{outcomes}\n"
        )
        return subprocess.run(
            ["bash", str(root / "scripts" / "docs-gate.sh"), "--plan", str(plan)],
            cwd=cwd or root,
            text=True,
            capture_output=True,
            check=False,
        )

    return invoke


def test_complete_gate_passes_from_another_directory(run_gate, tmp_path):
    result = run_gate(cwd=tmp_path)
    assert result.returncode == 0, result.stderr
    assert "PASS" in result.stdout


@pytest.mark.parametrize("case", ["missing", "duplicate", "unrelated"])
def test_missing_duplicate_and_unrelated_items_fail(run_gate, case):
    items = ITEMS.copy()
    if case == "missing":
        del items["ADR"]
    elif case == "duplicate":
        items["extra"] = items["README"]
    else:
        items["extra"] = "- [x] Other: evidence: README.md | Some update"
    assert run_gate(items).returncode != 0


@pytest.mark.parametrize(
    "line",
    [
        "- [x] README:",
        "- [x] README: evidence: README.md |",
        "- [x] README: evidence: absent.md | Public setup steps updated",
        "- [x] README: evidence: ../outside.md | Public setup steps updated",
        "- [x] README: evidence: linked.md | Public setup steps updated",
        "- [x] README: evidence: /tmp/outside.md | Public setup steps updated",
        "- [x] README: evidence: README.md | later",
        "- [x] README: evidence: README.md | updated",
    ],
)
def test_checked_item_requires_real_in_repo_file_and_description(run_gate, line):
    assert run_gate({**ITEMS, "README": line}).returncode != 0


@pytest.mark.parametrize(
    ("label", "line"),
    [
        ("ADR", "- [ ] ADR: skip:"),
        ("ADR", "- [ ] ADR: skip: later"),
        ("ADR", "- [ ] ADR: skip: none"),
        ("ADR", "- [ ] ADR: skip: <reason>"),
        ("Plan", "- [ ] Plan: skip: Plan is unfinished"),
    ],
)
def test_skip_requires_specific_reason_and_plan_cannot_skip(run_gate, label, line):
    assert run_gate({**ITEMS, label: line}).returncode != 0


def test_plan_evidence_must_be_supplied_plan(run_gate):
    result = run_gate(
        {**ITEMS, "Plan": "- [x] Plan: evidence: README.md | Progress and Outcomes recorded"}
    )
    assert result.returncode != 0


@pytest.mark.parametrize(
    ("progress", "outcomes"),
    [
        ("", "The docs gate is verified."),
        ("Implemented and validated.", "<Pending outcome>"),
    ],
)
def test_plan_progress_and_outcomes_must_be_filled(run_gate, progress, outcomes):
    assert run_gate(progress=progress, outcomes=outcomes).returncode != 0
