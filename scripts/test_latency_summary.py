"""Tests für latency_summary.py (#534, Schnitt 1).

Aufruf: python3 scripts/test_latency_summary.py
Feste Beispielwerte; die Mess-Suite selbst läuft nur mit dem echten Modell (`sim.sh real-model-latency`).
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "latency_summary.py"
sys.path.insert(0, str(SCRIPTS))


def write(folder, name, rows):
    (Path(folder) / name).write_text(json.dumps(rows))


def row(gruppe, sekunden, fehler=None):
    r = {"gruppe": gruppe, "note": "n", "sekunden": sekunden}
    if fehler:
        r["fehler"] = fehler
    return r


class SummaryTests(unittest.TestCase):
    def test_statistics_per_group(self):
        import latency_summary
        rows = [row("kalt", 3.0), row("kalt", 5.0), row("warm", 1.0), row("warm", 2.0), row("warm", 3.0), row("warm", 4.0)]
        out = latency_summary.summarize(rows)
        self.assertEqual(out["kalt"]["n"], 2)
        self.assertEqual(out["kalt"]["min"], 3.0)
        self.assertEqual(out["kalt"]["max"], 5.0)
        self.assertEqual(out["kalt"]["median"], 4.0)
        self.assertEqual(out["warm"]["n"], 4)
        self.assertEqual(out["warm"]["median"], 2.5)
        self.assertEqual(out["warm"]["max"], 4.0)
        self.assertIn("p95", out["warm"])

    def test_failed_probes_are_counted_apart(self):
        import latency_summary
        rows = [row("kalt", 3.0), row("warm", 1.0), row("warm", 40.0, fehler="timeout")]
        out = latency_summary.summarize(rows)
        self.assertEqual(out["warm"]["n"], 1)
        self.assertEqual(out["warm"]["fehler"], 1)
        self.assertEqual(out["warm"]["max"], 1.0)

    def test_cli_reads_a_folder(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "lauf-01.json", [row("kalt", 3.0), row("warm", 1.0)])
            write(d, "lauf-02.json", [row("kalt", 4.0), row("warm", 2.0)])
            run = subprocess.run([sys.executable, str(SCRIPT), d], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("kalt", run.stdout)
        self.assertIn("warm", run.stdout)

    def test_empty_folder_fails_with_message(self):
        with tempfile.TemporaryDirectory() as d:
            run = subprocess.run([sys.executable, str(SCRIPT), d], capture_output=True, text=True)
        self.assertNotEqual(run.returncode, 0)
        self.assertTrue(run.stderr.strip())

    def test_missing_group_fails_with_message(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "lauf-01.json", [row("kalt", 3.0)])
            run = subprocess.run([sys.executable, str(SCRIPT), d], capture_output=True, text=True)
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("warm", run.stderr)


if __name__ == "__main__":
    unittest.main()
