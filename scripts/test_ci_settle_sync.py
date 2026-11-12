"""Tests: der Schritt „Let the simulator settle“ bricht nicht ab, wenn kein Poster-Prozess läuft (#799).

Aufruf: python3 scripts/test_ci_settle_sync.py

Composite-Schritte mit `shell: bash` laufen als `bash --noprofile --norc -e -o pipefail`. `grep` liefert ohne Treffer
Exit 1; in der Zeile `busy=$(ps … | grep -i poster | …)` beendet das den ganzen Schritt, bevor die Schleife den guten
Fall „kein Prozess, ruhig“ erreicht (PR #797, Lauf 41347564840). Die Zeile steht in der Action und im Job `ui-smoke-shard`
von ci.yml; beide müssen gleich und geschützt sein.
"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACTION = ROOT / ".github" / "actions" / "prepare-ui-simulator" / "action.yml"
CI = ROOT / ".github" / "workflows" / "ci.yml"


def busy_line(path):
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip().startswith("busy=$(")]
    assert len(lines) == 1, f"{path.name}: erwartet genau eine busy=-Zeile, gefunden {len(lines)}"
    return lines[0]


class SettleStepTests(unittest.TestCase):
    def test_busy_lines_identical(self):
        self.assertEqual(busy_line(ACTION), busy_line(CI))

    def test_action_header_names_the_case(self):
        header = "\n".join(ACTION.read_text(encoding="utf-8").splitlines()[:8])
        self.assertIn("pipefail", header)
        self.assertIn("|| true", header)

    def test_grep_is_guarded(self):
        for path in (ACTION, CI):
            line = busy_line(path)
            for match in re.finditer(r"\bgrep\b", line):
                self.assertRegex(line[max(0, match.start() - 2):], r"^\{ grep [^}]*\|\| true; \}",
                                 f"{path.name}: grep ohne `|| true` in der busy=-Zeile")

    def test_no_match_exits_zero_under_pipefail(self):
        for path in (ACTION, CI):
            line = busy_line(path).replace("poster", "kein-prozess-dieses-namens-799")
            run = subprocess.run(["bash", "--noprofile", "--norc", "-e", "-o", "pipefail", "-c", line + '\necho "busy=$busy"'],
                                 capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, f"{path.name}: Exit {run.returncode}, {run.stderr}")
            self.assertEqual(run.stdout.strip(), "busy=0")


if __name__ == "__main__":
    unittest.main()
