"""Tests: scripts/next-ticket.sh schlägt das nächste Ticket des Epics vor (#715 Schnitt 1).

Aufruf: python3 scripts/test_next_ticket.py

`gh`, `herdr` und `git` sind Attrappen im PATH, die feste Antworten aus einer JSON-Datei geben. Das Skript
läuft sonst unverändert; das Sperrverzeichnis liegt im Temp-Ordner (`LOOSEENDS_LOCKS_DIR`), die eigene
Sitzung kommt aus `CLAUDE_SESSION_ID`.
"""
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "next-ticket.sh"

GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
if os.environ.get("GH_FAIL"):
    sys.stderr.write("gh: simulated failure\n")
    sys.exit(1)
fx = json.load(open(os.environ["FIXTURE"]))
a = " ".join(sys.argv[1:])
def out(v):
    print(json.dumps(v)); sys.exit(0)
def num(pattern):
    import re
    m = re.search(pattern, a)
    return m.group(1) if m else None
if "/sub_issues" in a:
    out(fx["sub_issues"].get(num(r"issues/(\d+)/sub_issues"), []))
if a.endswith("/parent") or "/parent " in a + " ":
    n = num(r"issues/(\d+)/parent")
    if n in fx["parent"]:
        out({"number": fx["parent"][n]})
    sys.stderr.write("gh: Not Found (HTTP 404)\n"); sys.exit(1)
if "/dependencies/blocked_by" in a:
    out(fx["blocked_by"].get(num(r"issues/(\d+)/dependencies"), []))
if a.startswith("project item-list"):
    out({"items": [{"content": {"number": b["number"], "type": "Issue"}, "status": b.get("status", "Ready"),
                    "priority": b.get("priority", "P1")} for b in fx["board"]]})
if a.startswith("pr list"):
    out([{"number": p["number"], "title": p.get("title", ""), "body": p.get("body", ""),
          "headRefName": p.get("branch", "")} for p in fx["prs"]])
if a.startswith("pr diff"):
    n = int(num(r"pr diff (\d+)"))
    for p in fx["prs"]:
        if p["number"] == n:
            print("\n".join(p.get("files", []))); sys.exit(0)
    sys.exit(1)
sys.stderr.write("gh stub: unknown call: " + a + "\n"); sys.exit(2)
'''

HERDR_STUB = r'''#!/usr/bin/env python3
import json, os, sys
a = sys.argv[1:]
if a[:2] == ["workspace", "get"]:
    print(json.dumps({"workspace": {"label": os.environ.get("HERDR_LABEL", "")}}))
    sys.exit(0)
if a[:1] == ["notification"]:
    with open(os.environ["HERDR_LOG"], "a") as f:
        f.write(" ".join(a) + "\n")
    sys.exit(0)
sys.exit(2)
'''

GIT_STUB = r'''#!/usr/bin/env python3
import json, os, re, sys
fx = json.load(open(os.environ["FIXTURE"]))
a = " ".join(sys.argv[1:])
m = re.search(r"diff --name-only main\.\.\.(\S+)", a)
if m:
    print("\n".join(fx.get("git", {}).get(m.group(1), [])))
    sys.exit(0)
sys.exit(0)
'''


def epic_fixture(**over):
    """Epic 371 mit den Teil-Tickets 342, 176, 40, alle frei, Board-Reihenfolge 342, 176, 40."""
    fx = {
        "sub_issues": {"371": [{"number": n, "title": f"Ticket {n}", "state": "open"} for n in (342, 176, 40)]},
        "parent": {"176": 371, "342": 371, "40": 371},
        "blocked_by": {},
        "board": [{"number": 342, "priority": "P1"}, {"number": 176, "priority": "P1"}, {"number": 40, "priority": "P1"}],
        "prs": [],
        "git": {},
    }
    fx.update(over)
    return fx


class NextTicket(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        self.locks = self.dir / "locks"
        self.locks.mkdir()
        for name, body in (("gh", GH_STUB), ("herdr", HERDR_STUB), ("git", GIT_STUB)):
            path = self.bin / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IXUSR)
        self.herdr_log = self.dir / "herdr.log"

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, fixture, label="#371 Texte", fail=False, workspace="w3"):
        fx = self.dir / "fixture.json"
        fx.write_text(json.dumps(fixture))
        env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "FIXTURE": str(fx),
            "HERDR_LABEL": label,
            "HERDR_LOG": str(self.herdr_log),
            "LOOSEENDS_LOCKS_DIR": str(self.locks),
            "LOOSEENDS_REPO": "henemm/loose-ends",
            "CLAUDE_SESSION_ID": "own-session",
        }
        env.pop("GH_FAIL", None)
        if fail:
            env["GH_FAIL"] = "1"
        if workspace:
            env["HERDR_WORKSPACE_ID"] = workspace
        else:
            env.pop("HERDR_WORKSPACE_ID", None)
        return subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True, timeout=60)

    def lock(self, session, issue, phase, pid, branch=""):
        (self.locks / f"{session}.json").write_text(json.dumps(
            {"session_id": session, "pid": pid, "issue": str(issue), "phase": phase, "branch": branch}))

    def first_line(self, result):
        return result.stdout.splitlines()[0] if result.stdout else ""

    # AC-1
    def test_epic_from_label_with_epic_number(self):
        r = self.run_script(epic_fixture())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.first_line(r), "NEXT=#342", r.stdout + r.stderr)

    # AC-2
    def test_epic_from_label_with_ticket_number(self):
        r = self.run_script(epic_fixture(), label="#176 Abnahme")
        self.assertEqual(self.first_line(r), "NEXT=#342", r.stdout + r.stderr)

    # AC-8
    def test_no_epic_gives_none(self):
        r = self.run_script(epic_fixture(), label="Restock")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.first_line(r), "NEXT=none")
        self.assertIn("kein Epic", r.stdout)
        r = self.run_script(epic_fixture(), label="#715 Nächstes Ticket")
        self.assertEqual(self.first_line(r), "NEXT=none")
        self.assertIn("kein Epic", r.stdout)

    # AC-3
    def test_in_progress_and_pr_are_skipped(self):
        fx = epic_fixture(
            board=[{"number": 342, "status": "In progress", "priority": "P1"},
                   {"number": 176, "priority": "P1"}, {"number": 40, "priority": "P1"}],
            prs=[{"number": 900, "body": "Closes #176", "files": []}])
        r = self.run_script(fx)
        self.assertEqual(self.first_line(r), "NEXT=#40", r.stdout)
        self.assertIn("#342", r.stdout)
        self.assertIn("#176", r.stdout)

    # AC-4
    def test_live_session_lock_blocks_finished_lock_does_not(self):
        dead = subprocess.Popen(["true"])
        dead.wait()
        self.lock("other-live", 342, "phase6_implement", os.getpid())
        self.lock("other-finished", 176, "phase8_complete", os.getpid())
        self.lock("other-dead", 40, "phase6_implement", dead.pid)
        r = self.run_script(epic_fixture())
        self.assertEqual(self.first_line(r), "NEXT=#176", r.stdout)
        self.assertIn("#342", r.stdout)

    def test_own_lock_does_not_block(self):
        self.lock("own-session", 342, "phase6_implement", os.getpid())
        r = self.run_script(epic_fixture())
        self.assertEqual(self.first_line(r), "NEXT=#342", r.stdout)

    # AC-5
    def test_blocked_by_is_skipped_and_named(self):
        fx = epic_fixture(blocked_by={"342": [{"number": 999, "state": "open"}],
                                      "176": [{"number": 888, "state": "closed"}]})
        r = self.run_script(fx)
        self.assertEqual(self.first_line(r), "NEXT=#176", r.stdout)
        self.assertIn("#999", r.stdout)

    # AC-6
    def test_order_priority_then_board_position(self):
        fx = epic_fixture(board=[{"number": 342, "priority": "P1"}, {"number": 176, "priority": "P2"},
                                 {"number": 40, "priority": "P0"}])
        self.assertEqual(self.first_line(self.run_script(fx)), "NEXT=#40")
        fx = epic_fixture(board=[{"number": 40, "priority": "P1"}, {"number": 342, "priority": "P1"},
                                 {"number": 176, "priority": "P1"}])
        self.assertEqual(self.first_line(self.run_script(fx)), "NEXT=#40")

    # AC-7
    def test_overlap_with_open_pr_is_reported(self):
        fx = epic_fixture(prs=[
            {"number": 901, "body": "Closes #500", "branch": "work/500", "files": ["project.yml", "Shared/A.swift"]},
            {"number": 902, "body": "Closes #501", "branch": "work/501", "files": ["Shared/B.swift"]}])
        r = self.run_script(fx)
        self.assertEqual(self.first_line(r), "NEXT=#342", r.stdout)
        self.assertIn("project.yml", r.stdout)
        self.assertIn("#901", r.stdout)
        self.assertNotIn("#902", r.stdout)

    def test_overlap_with_live_session_branch_is_reported(self):
        self.lock("other-live", 500, "phase6_implement", os.getpid(), branch="work/500")
        r = self.run_script(epic_fixture(git={"work/500": ["cloudkit/schema.ckdb"]}))
        self.assertIn("cloudkit/schema.ckdb", r.stdout)
        self.assertIn("work/500", r.stdout)

    # AC-8
    def test_all_blocked_gives_none_and_notifies(self):
        fx = epic_fixture(blocked_by={str(n): [{"number": 999, "state": "open"}] for n in (342, 176, 40)})
        r = self.run_script(fx)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.first_line(r), "NEXT=none")
        self.assertIn("#999", r.stdout)
        self.assertTrue(self.herdr_log.exists() and "notification" in self.herdr_log.read_text())

    # AC-9
    def test_api_failure_gives_unknown_exit_zero(self):
        r = self.run_script(epic_fixture(), fail=True)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.first_line(r), "NEXT=unknown")
        self.assertGreater(len(r.stdout.splitlines()), 1)

    def test_missing_workspace_gives_none(self):
        r = self.run_script(epic_fixture(), workspace=None)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.first_line(r), "NEXT=none")

    # AC-10
    def test_first_line_is_machine_readable(self):
        pattern = re.compile(r"^NEXT=(#[0-9]+|none|unknown)$")
        for kwargs in ({}, {"label": "Restock"}, {"fail": True}):
            r = self.run_script(epic_fixture(), **kwargs)
            self.assertRegex(self.first_line(r), pattern)

    # AC-11
    def test_claude_md_names_script_and_epic_rule(self):
        text = (ROOT / "CLAUDE.md").read_text()
        process = text.split("## Process", 1)[1].split("\n## ", 1)[0]
        self.assertIn("scripts/next-ticket.sh", process)
        self.assertRegex(process, r"Epic")


if __name__ == "__main__":
    sys.exit(unittest.main())
