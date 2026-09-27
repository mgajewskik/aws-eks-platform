"""Check the mechanical evidence contract in a plan's Docs gate section."""

import argparse
import re
import sys
from pathlib import Path


LABELS = ("Plan", "Architecture", "Runbook", "ADR", "Glossary", "README")
ITEM = re.compile(r"^\s*-\s+\[([xX ])\]\s+([^:]+):\s*(.*)$")
PLACEHOLDER = re.compile(r"<[^>]+>|\.{3}|\b(?:later|todo|tbd|pending)\b", re.IGNORECASE)


def error(message):
    print(f"docs-gate: {message}", file=sys.stderr)


def section(text, heading):
    matches = list(re.finditer(rf"^## {re.escape(heading)}\s*$", text, re.MULTILINE))
    if len(matches) != 1:
        raise ValueError(f"expected exactly one '## {heading}' section")
    start = matches[0].end()
    next_heading = re.search(r"^## ", text[start:], re.MULTILINE)
    return text[start : start + next_heading.start()] if next_heading else text[start:]


def useful(value):
    return bool(value.strip()) and not PLACEHOLDER.search(value)


def specific(value):
    words = re.findall(r"\b[\w-]+\b", value)
    return useful(value) and len(words) >= 2 and value.strip().lower() not in {"not applicable", "not needed"}


def check(plan, root):
    text = plan.read_text(encoding="utf-8")
    lines = section(text, "Docs gate").splitlines()
    seen = set()
    failures = []

    for line in lines:
        if not re.match(r"^\s*-\s+\[", line):
            continue
        match = ITEM.fullmatch(line)
        if not match:
            failures.append(f"invalid checklist item: {line.strip()}")
            continue
        checked, label, detail = match.groups()
        label = label.strip()
        if label not in LABELS:
            failures.append(f"unexpected Docs gate item: {label}")
            continue
        if label in seen:
            failures.append(f"duplicate Docs gate item: {label}")
            continue
        seen.add(label)

        if checked != " ":
            evidence = re.fullmatch(r"evidence:\s*(.*?)\s*\|\s*(.*)", detail)
            if not evidence or not useful(evidence.group(1)) or not specific(evidence.group(2)):
                failures.append(f"{label}: checked item needs evidence: <path> | <specific description>")
                continue
            path = Path(evidence.group(1))
            if path.is_absolute():
                failures.append(f"{label}: evidence path must be repository-relative")
                continue
            resolved = (root / path).resolve()
            if not resolved.is_relative_to(root) or not resolved.is_file():
                failures.append(f"{label}: evidence file is missing or outside repository: {path}")
            elif label == "Plan" and resolved != plan:
                failures.append("Plan: evidence must point to the supplied plan")
        elif label == "Plan":
            failures.append("Plan: cannot be skipped")
        elif not detail.startswith("skip:") or not specific(detail.removeprefix("skip:")):
            failures.append(f"{label}: unchecked item needs skip: <specific reason>")

    for label in LABELS:
        if label not in seen:
            failures.append(f"missing Docs gate item: {label}")
    for heading in ("Progress", "Outcomes"):
        try:
            if not useful(section(text, heading)):
                failures.append(f"{heading} section has no completed content")
        except ValueError as exc:
            failures.append(str(exc))

    for failure in failures:
        error(failure)
    return not failures


def main():
    parser = argparse.ArgumentParser(prog="docs-gate.sh")
    parser.add_argument("--plan", required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    plan = args.plan.resolve()
    if not plan.is_file():
        error(f"plan not found: {args.plan}")
        return 1
    try:
        passed = check(plan, root)
    except (OSError, UnicodeError, ValueError) as exc:
        error(str(exc))
        return 1
    if passed:
        print(f"docs-gate: PASS {args.plan}")
        return 0
    error(f"FAIL {args.plan}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
