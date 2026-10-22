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


def lab_result(seconds, thermal="normal", power="akku", error=None):
    r = {"entryID": "lat-01", "seconds": seconds, "conditions": {"thermal": thermal, "power": power}}
    if error:
        r["error"] = error
    return r


def write_lab(folder, name, results):
    (Path(folder) / name).write_text(json.dumps({"name": name, "results": results, "events": []}))


class LabFormatTests(unittest.TestCase):
    """Labor-App-Format (#534, Schnitt 2): je Datei ein Start, der erste Aufruf ist kalt."""

    def test_first_result_per_file_is_cold(self):
        import latency_summary
        with tempfile.TemporaryDirectory() as d:
            write_lab(d, "latency-01.json", [lab_result(9.0), lab_result(8.0), lab_result(7.0)])
            write_lab(d, "latency-02.json", [lab_result(11.0), lab_result(6.0)])
            out = latency_summary.summarize(latency_summary.read_folder(d))
        self.assertEqual(out["kalt"]["n"], 2)
        self.assertEqual(out["kalt"]["max"], 11.0)
        self.assertEqual(out["warm"]["n"], 3)
        self.assertEqual(out["warm"]["max"], 8.0)

    def test_errors_are_counted_apart(self):
        import latency_summary
        with tempfile.TemporaryDirectory() as d:
            write_lab(d, "latency-01.json", [lab_result(9.0), lab_result(30.0, error="timeout"), lab_result(7.0)])
            out = latency_summary.summarize(latency_summary.read_folder(d))
        self.assertEqual(out["warm"]["n"], 1)
        self.assertEqual(out["warm"]["fehler"], 1)
        self.assertEqual(out["warm"]["max"], 7.0)

    def test_max_by_thermal_and_power_counts(self):
        import latency_summary
        with tempfile.TemporaryDirectory() as d:
            write_lab(d, "latency-01.json", [
                lab_result(9.0), lab_result(8.0), lab_result(14.0, thermal="serious", power="strom")])
            out = latency_summary.summarize(latency_summary.read_folder(d))
        self.assertEqual(out["warm"]["max_by_thermal"], {"normal": 8.0, "serious": 14.0})
        self.assertEqual(out["warm"]["power"], {"akku": 1, "strom": 1})

    def test_cli_prints_thermal_breakdown(self):
        with tempfile.TemporaryDirectory() as d:
            write_lab(d, "latency-01.json", [lab_result(9.0), lab_result(14.0, thermal="serious")])
            run = subprocess.run([sys.executable, str(SCRIPT), d], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("serious", run.stdout)


if __name__ == "__main__":
    unittest.main()
