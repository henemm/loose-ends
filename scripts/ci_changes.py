#!/usr/bin/env python3
"""#995: does a pull request need the app jobs of ci.yml?

Reads the changed paths (one per line) on stdin and prints `app=true` or `app=false` for $GITHUB_OUTPUT.
Only these paths spare the app jobs: docs/, server/ (own workflow), .claude/, .github/ (a push to main runs
everything), top-level *.md, and scripts/ except the files ci.yml itself calls. Anything else, an empty or
unreadable list included, means app=true: when in doubt, everything runs.
"""
import re
import sys
from pathlib import Path

CI = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "ci.yml"
SPARED_DIRS = ("docs/", "server/", ".claude/", ".github/")


def ci_scripts(ci_text: str) -> set:
    """The scripts ci.yml runs itself: a change to one of them changes the app jobs.

    This file is left out: it only makes the decision, and its own tests run in every pull request."""
    return set(re.findall(r"scripts/[A-Za-z0-9_.-]+\.[A-Za-z]+", ci_text)) - {"scripts/ci_changes.py"}


def needs_app(paths, ci_text: str) -> bool:
    paths = [p.strip() for p in paths if p.strip()]
    if not paths:
        return True
    used = ci_scripts(ci_text)
    for path in paths:
        if path.startswith(SPARED_DIRS):
            continue
        if "/" not in path and path.endswith(".md"):
            continue
        if path.startswith("scripts/") and path not in used and path != "scripts/sim.sh":
            continue
        return True
    return False


def main() -> int:
    app = needs_app(sys.stdin.read().splitlines(), CI.read_text())
    print(f"app={'true' if app else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
