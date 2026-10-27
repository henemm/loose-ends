"""Tests: scripts/next-ticket-hook.sh legt den Vorschlag nach /clear in den Kontext (#715 Schnitt 2).

Aufruf: python3 scripts/test_next_ticket_hook.py

`next-ticket.sh` ist eine Attrappe (`LOOSEENDS_NEXT_TICKET`), `herdr` eine Attrappe im PATH. Der Hauptcheckout ist ein
Temp-Ordner (`LOOSEENDS_CHECKOUT`; `LOOSEENDS_REPO` bleibt das GitHub-Repo des Skripts und wird nicht angefasst).
Kein Netz, keine Datei außerhalb des Temp-Ordners.
"""
import json
import os
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOOK = ROOT / "scripts" / "next-ticket-hook.sh"

HERDR_STUB = r'''#!/usr/bin/env python3
import json, os, sys
a = sys.argv[1:]
if a[:2] == ["workspace", "get"]:
    print(json.dumps({"id": "cli:workspace:get", "result": {"type": "workspace_info",
                      "workspace": {"label": os.environ.get("HERDR_LABEL", ""), "workspace_id": a[2]}}}))
    sys.exit(0)
sys.exit(2)
'''

# Die Attrappe von next-ticket.sh hält fest, mit welcher Sitzungskennung sie gerufen wurde.
SCRIPT_STUB = r'''#!/bin/bash
echo "${CLAUDE_SESSION_ID-<unset>}" > "$STUB_LOG"
[ -n "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
[ -n "${STUB_EXIT:-}" ] && exit "$STUB_EXIT"
printf '%s\n' "${STUB_OUTPUT:-NEXT=#40}"
echo "Titel: Icon-Paket"
exit 0
'''

NOTICE = "Hinweis, kein Auftrag"

OLD_ENTRIES = [
    {"hooks": [{"type": "command", "command": "bash /Users/hem/.claude/scripts/loose-ends-sync-main.sh"}]},
    {"matcher": "^(startup|resume|clear|compact|fork)$",
     "hooks": [{"type": "command", "command": "bash '/Users/hem/.claude/hooks/herdr-agent-state.sh' session",
                "timeout": 10}]},
]


def write_exec(path, text):
    path.write_text(text)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class HookTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        t = Path(self.tmp.name)
        self.checkout = t / "loose-ends"
        (self.checkout / "wt").mkdir(parents=True)
        self.bin = t / "bin"
        self.bin.mkdir()
        write_exec(self.bin / "herdr", HERDR_STUB)
        self.script = t / "next-ticket-stub.sh"
        write_exec(self.script, SCRIPT_STUB)
        self.log = t / "stub.log"

    def run_hook(self, stdin=None, cwd=None, label="#371 Texte", workspace="w3", **env):
        payload = {"session_id": "abc-123", "cwd": str(cwd or self.checkout / "wt"), "source": "clear"}
        if isinstance(stdin, dict):
            payload.update(stdin)
            stdin = None
        e = {"PATH": f"{self.bin}:{os.environ['PATH']}", "HOME": self.tmp.name,
             "LOOSEENDS_CHECKOUT": str(self.checkout), "LOOSEENDS_NEXT_TICKET": str(self.script),
             "STUB_LOG": str(self.log), "HERDR_LABEL": label}
        if workspace:
            e["HERDR_WORKSPACE_ID"] = workspace
        e.update(env)
        start = time.monotonic()
        r = subprocess.run(["bash", str(HOOK)], input=stdin if stdin is not None else json.dumps(payload),
                           capture_output=True, text=True, env=e, timeout=60)
        r.elapsed = time.monotonic() - start
        return r

    def assert_silent(self, r):
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "", r.stdout)

    def context_of(self, r):
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout)
        self.assertEqual(out["hookSpecificOutput"]["hookEventName"], "SessionStart")
        return out["hookSpecificOutput"]["additionalContext"]

    def test_session_id_from_stdin_reaches_script(self):  # AC-4
        self.run_hook()
        self.assertEqual(self.log.read_text().strip(), "abc-123")

    def test_normal_case_outputs_additional_context_with_notice(self):  # AC-5
        ctx = self.context_of(self.run_hook())
        self.assertIn(NOTICE, ctx)
        self.assertIn("NEXT=#40", ctx)
        self.assertIn("Icon-Paket", ctx)

    def test_startup_source_is_served_too(self):  # AC-5
        self.assertIn("NEXT=#40", self.context_of(self.run_hook({"source": "startup"})))

    def test_none_is_passed_on(self):  # AC-5
        ctx = self.context_of(self.run_hook(STUB_OUTPUT="NEXT=none"))
        self.assertIn(NOTICE, ctx)
        self.assertIn("NEXT=none", ctx)

    def test_other_source_is_silent(self):  # AC-6
        for source in ("resume", "compact"):
            with self.subTest(source=source):
                self.assert_silent(self.run_hook({"source": source}))
                self.assertFalse(self.log.exists(), "Skript darf nicht gerufen werden")

    def test_foreign_project_is_silent(self):  # AC-6
        self.assert_silent(self.run_hook(cwd=Path(self.tmp.name)))
        self.assertFalse(self.log.exists())

    def test_label_without_number_is_silent(self):  # AC-6
        self.assert_silent(self.run_hook(label="Restock"))
        self.assertFalse(self.log.exists())

    def test_no_herdr_workspace_is_silent(self):  # AC-6
        self.assert_silent(self.run_hook(workspace=None))
        self.assertFalse(self.log.exists())

    def test_unknown_is_silent(self):  # AC-7
        self.assert_silent(self.run_hook(STUB_OUTPUT="NEXT=unknown"))

    def test_timeout_is_silent_and_bounded(self):  # AC-7
        r = self.run_hook(STUB_SLEEP="20", LOOSEENDS_NEXT_TIMEOUT="1")
        self.assert_silent(r)
        self.assertLess(r.elapsed, 3, f"Adapter blieb {r.elapsed:.1f} s")

    def test_script_failure_is_silent(self):  # AC-8
        self.assert_silent(self.run_hook(STUB_EXIT="3"))

    def test_bad_stdin_is_silent(self):  # AC-8
        self.assert_silent(self.run_hook(stdin="das ist kein JSON"))
        self.assert_silent(self.run_hook(stdin=""))

    def test_settings_has_third_entry_and_keeps_others(self):  # AC-9
        path = Path.home() / ".claude" / "settings.json"
        if not path.exists():
            self.skipTest("keine ~/.claude/settings.json (CI)")
        entries = json.loads(path.read_text())["hooks"]["SessionStart"]
        self.assertEqual(len(entries), 3)
        self.assertEqual(entries[:2], OLD_ENTRIES)
        new = entries[2]
        self.assertEqual(new["matcher"], "^(startup|clear)$")
        hook = new["hooks"][0]
        self.assertEqual(hook["timeout"], 30)
        self.assertIn("scripts/next-ticket-hook.sh", hook["command"])


if __name__ == "__main__":
    sys.exit(unittest.main(verbosity=2))
