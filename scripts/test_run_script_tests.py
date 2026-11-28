"""Tests für den parallelen Läufer der Skripttests (#995).

Aufruf: python3 scripts/test_run_script_tests.py
Die Testfälle starten den Läufer nur gegen eigene Temp-Verzeichnisse, nie gegen scripts/ selbst.
"""
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "run_script_tests.py"

GREEN = "import unittest\nclass T(unittest.TestCase):\n    def test_ok(self):\n        self.assertTrue(True)\n"
RED = ("import unittest\nclass T(unittest.TestCase):\n    def test_bad(self):\n"
       "        self.assertEqual(1, 2, 'RED-MARKER')\n")
SLEEPY = ("import time, unittest\nclass T(unittest.TestCase):\n    def test_sleep(self):\n"
          "        time.sleep(30)\n")


def run(folder, **env):
    full = dict(os.environ, **env)
    return subprocess.run([sys.executable, str(RUNNER), str(folder)], capture_output=True, text=True,
                          env=full, timeout=120)


def last_line(result):
    lines = [l for l in result.stdout.splitlines() if l.strip()]
    return lines[-1] if lines else ""


def load_runner():
    import importlib.util
    spec = importlib.util.spec_from_file_location("run_script_tests", RUNNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RunnerTests(unittest.TestCase):
    def test_finds_exactly_the_glob_modules(self):
        """AC-1: dieselben Module wie glob scripts/test_*.py, keine anderen."""
        expected = sorted(p.stem for p in HERE.glob("test_*.py"))
        self.assertEqual(sorted(load_runner().modules(HERE)), expected)

    def test_red_module_fails_the_run_and_is_named(self):
        """AC-2: Exit 1, volle Ausgabe des roten Moduls, Schlusszeile nennt nur es."""
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "test_good.py").write_text(GREEN)
            Path(tmp, "test_broken.py").write_text(RED)
            result = run(tmp)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("RED-MARKER", result.stdout)
        self.assertIn("test_broken", last_line(result))
        self.assertNotIn("test_good", last_line(result))

    def test_empty_folder_fails(self):
        """AC-3: kein Testmodul → Exit 1."""
        with tempfile.TemporaryDirectory() as tmp:
            result = run(tmp)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_hanging_module_hits_the_limit(self):
        """AC-4: Zeitlimit überschritten → Exit 1, Modul rot, Lauf endet lange vor dem Schlafende."""
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "test_good.py").write_text(GREEN)
            Path(tmp, "test_sleepy.py").write_text(SLEEPY)
            start = time.monotonic()
            result = run(tmp, SCRIPT_TESTS_TIMEOUT="2")
            took = time.monotonic() - start
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("test_sleepy", last_line(result))
        self.assertLess(took, 20)

    def test_all_green_passes(self):
        """Zwei grüne Module → Exit 0, Schlusszeile: 2 Module, 0 rot."""
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "test_one.py").write_text(GREEN)
            Path(tmp, "test_two.py").write_text(GREEN)
            result = run(tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(last_line(result), r"\b2\b.*\b0\b")

    def test_worker_count(self):
        """SCRIPT_TESTS_WORKERS gewinnt, sonst max(4, min(8, Kerne))."""
        runner = load_runner()
        self.assertEqual(runner.workers({"SCRIPT_TESTS_WORKERS": "2"}, cpu=10), 2)
        self.assertEqual(runner.workers({}, cpu=3), 4)
        self.assertEqual(runner.workers({}, cpu=6), 6)
        self.assertEqual(runner.workers({}, cpu=16), 8)
        self.assertEqual(runner.workers({}, cpu=None), 4)


if __name__ == "__main__":
    unittest.main()
