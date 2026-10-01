"""Tests für sim_proof.py und die Fehlerfälle von `sim.sh test-proof` (#145, Schnitt 1).

Aufruf: python3 -m unittest scripts/test_sim_proof.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
try:
    import sim_proof
except ModuleNotFoundError:
    sim_proof = None

# Wörtlich aus dem Plugin (adversary_dialog.py:573); Schnitt 2 liest den Beleg damit.
PLUGIN_HASH_RE = re.compile(r"(?m)^-\s*sha256:([0-9a-f]{64})\s+(.+?)\s*$")

PASSED = {
    "result": "Passed", "startTime": 1759320000.5, "finishTime": 1759320042.0,
    "totalTestCount": 3, "passedTests": 3, "failedTests": 0, "skippedTests": 0,
    "devicesAndConfigurations": [{"device": {"deviceName": "iPhone 17", "osVersion": "27.0"}}],
    "testFailures": [],
}
FAILED = dict(PASSED, result="Failed", passedTests=2, failedTests=1,
              testFailures=[{"testName": "testCapture()", "failureText": "XCTAssertTrue failed"}])


class NeedsModule(unittest.TestCase):
    def setUp(self):
        if sim_proof is None:
            self.fail("scripts/sim_proof.py fehlt")


class SummaryParsingTests(NeedsModule):
    def test_passed_summary_gives_counts_device_and_times(self):
        s = sim_proof.parse_summary(PASSED, xcodebuild_exit=0)
        self.assertEqual(s["ergebnis"], "Passed")
        self.assertEqual((s["gesamt"], s["bestanden"], s["fehlgeschlagen"], s["uebersprungen"]), (3, 3, 0, 0))
        self.assertEqual(s["geraet"], "iPhone 17, iOS 27.0")
        self.assertEqual((s["start"], s["ende"]), (1759320000.5, 1759320042.0))

    def test_failed_summary_is_failed(self):
        self.assertEqual(sim_proof.parse_summary(FAILED, xcodebuild_exit=65)["ergebnis"], "Failed")

    def test_missing_fields_do_not_crash_and_invent_nothing(self):
        s = sim_proof.parse_summary({"result": "Passed"}, xcodebuild_exit=0)
        self.assertEqual(s["ergebnis"], "Unbekannt")
        for key in ("gesamt", "bestanden", "fehlgeschlagen", "uebersprungen", "start", "ende", "geraet"):
            self.assertEqual(s[key], "unbekannt", key)

    def test_passed_with_failing_xcodebuild_is_not_passed(self):
        self.assertNotEqual(sim_proof.parse_summary(PASSED, xcodebuild_exit=65)["ergebnis"], "Passed")

    def test_passed_without_tests_is_not_passed(self):
        empty = dict(PASSED, totalTestCount=0, passedTests=0)
        self.assertNotEqual(sim_proof.parse_summary(empty, xcodebuild_exit=0)["ergebnis"], "Passed")


class CodeFilterTests(NeedsModule):
    """Spiegel von is_gated_code_path (Plugin hook_utils.py:710) mit den Vorgabelisten."""

    def test_product_and_test_sources_count_as_code(self):
        for path in ("LooseEnds/Views/Foo.swift", "Shared/Services/Bar.swift", "LooseEndsUITests/X.swift",
                     "LooseEndsTests/Y.swift", "Measurement/Z.swift", "LooseEnds/Views/Neue Datei.swift"):
            self.assertTrue(sim_proof.is_gated_code_path(path), path)

    def test_config_docs_and_scripts_do_not_count(self):
        for path in ("project.yml", "LooseEnds/Info.plist", "docs/a.swift", "scripts/sim_proof.py",
                     "README.md", "x.json", "notes.txt", "LooseEnds/Tests/T.swift", "a/UITests/U.swift"):
            self.assertFalse(sim_proof.is_gated_code_path(path), path)


class ProofFormatTests(NeedsModule):
    HEADER = {"erzeugt": "2026-10-01T14:03:11+0200", "testklasse": "CaptureSmokeTests", "ergebnis": "Passed"}

    def test_roundtrip_through_plugin_regex(self):
        files = [("a" * 64, "LooseEnds/Views/Foo.swift"), ("b" * 64, "LooseEnds/Views/Neue Datei.swift")]
        text = sim_proof.format_proof(self.HEADER, files)
        self.assertTrue(text.startswith("# Simulator-Beleg\n"))
        self.assertIn("ergebnis: Passed\n", text)
        self.assertIn("\n## Geprüfte Dateien\n", text)
        self.assertEqual(PLUGIN_HASH_RE.findall(text), files)

    def test_empty_file_set_is_explicit_and_matches_nothing(self):
        text = sim_proof.format_proof(self.HEADER, [])
        self.assertIn("## Geprüfte Dateien\n(keine Code-Dateien geändert)", text)
        self.assertEqual(PLUGIN_HASH_RE.findall(text), [])


class TestProofCommandErrorTests(unittest.TestCase):
    """`sim.sh test-proof` bricht ohne Klasse oder ohne Workflow ab, bevor irgendetwas läuft."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        (self.root / "scripts").mkdir()
        shutil.copy(SCRIPTS / "sim.sh", self.root / "scripts" / "sim.sh")
        stubs = self.root / "stubs"
        stubs.mkdir()
        self.marker = self.root / "tool-was-called"
        for tool in ("xcodebuild", "xcodegen", "xcrun", "xcbeautify"):
            stub = stubs / tool
            stub.write_text(f'#!/bin/bash\ntouch "{self.marker}"\nexit 0\n')
            stub.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{stubs}:/usr/bin:/bin", CLAUDE_PROJECT_DIR=str(self.root))

    def run_sim(self, *args):
        return subprocess.run(["bash", str(self.root / "scripts" / "sim.sh"), "test-proof", *args],
                              env=self.env, capture_output=True, text=True, timeout=60)

    def test_missing_class_fails_with_usage_and_keeps_old_proof(self):
        (self.root / ".claude").mkdir()
        (self.root / ".claude" / "active_workflow").write_text("wf-x\n")
        old = self.root / "docs" / "artifacts" / "wf-x" / "simulator-run.txt"
        old.parent.mkdir(parents=True)
        old.write_text("alt\n")
        r = self.run_sim()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("test-proof <Testklasse", r.stderr)
        self.assertFalse(self.marker.exists(), "Werkzeug lief trotz fehlender Klasse")
        self.assertEqual(old.read_text(), "alt\n")

    def test_missing_workflow_fails_before_any_run(self):
        r = self.run_sim("CaptureSmokeTests")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Kein aktiver Workflow", r.stderr)
        self.assertFalse(self.marker.exists(), "Werkzeug lief trotz fehlendem Workflow")


if __name__ == "__main__":
    unittest.main()
