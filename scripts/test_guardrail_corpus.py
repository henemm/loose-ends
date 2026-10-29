"""Tests für guardrail_corpus.py und den Befehl `sim.sh lab-guardrail` (#71, Schnitt 2b-2).

Aufruf: python3 -I scripts/test_guardrail_corpus.py
Alles mit erfundenen Sätzen und ohne Gerät: `xcrun` ist eine Attrappe, die jeden Aufruf als Fehler meldet.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
SCRIPT = SCRIPTS / "guardrail_corpus.py"
SIM = SCRIPTS / "sim.sh"
SENTENCES = ["Zahnarzt anrufen wegen Termin", "Geburtstagsgeschenk für Mama besorgen", "Rasen mähen am Samstag"]


def run_script(*args):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *args], capture_output=True, text=True)


def write_json(folder, name, data):
    path = Path(folder) / name
    path.write_text(json.dumps(data))
    return path


def focusblox(folder, sentences=SENTENCES):
    return write_json(folder, "fb.json", [{"lang": "de", "rawText": s} for s in sentences])


def heikel(n=100, prefix="gr-"):
    return [{"id": f"{prefix}{i:03d}", "lang": "de", "text": f"heikel {i}", "form": "kuendigung"} for i in range(1, n + 1)]


def result(entry, run, kind=None, error=None):
    r = {"entryID": entry, "runIndex": run}
    if error is not None:
        r["error"] = error
    if kind is not None:
        r["errorKind"] = kind
    return r


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_builds_103_entries_with_alltag_ids(self):
        target = Path(self.dir) / "out.json"
        proc = run_script("build", str(focusblox(self.dir)), str(target))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        entries = json.loads(target.read_text())
        self.assertEqual(len(entries), 103)
        alltag = [e for e in entries if e["form"] == "alltag"]
        self.assertEqual([e["id"] for e in alltag], ["alltag-0", "alltag-1", "alltag-2"])
        self.assertEqual([e["text"] for e in alltag], SENTENCES)
        for e in entries:
            self.assertEqual(set(e), {"id", "lang", "text", "form"})

    def test_stdout_has_numbers_but_no_sentence(self):
        target = Path(self.dir) / "out.json"
        proc = run_script("build", str(focusblox(self.dir)), str(target))
        for s in SENTENCES:
            self.assertNotIn(s, proc.stdout + proc.stderr)
        self.assertIn("103", proc.stdout)

    def assert_refused(self, *args, target):
        proc = run_script("build", *args)
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse(Path(target).exists(), "Zieldatei darf nicht angelegt sein")
        for s in SENTENCES:
            self.assertNotIn(s, proc.stdout + proc.stderr)

    def test_refuses_target_inside_repo(self):
        target = ROOT / "docs" / "artifacts" / "71-guardrails" / "never-written-by-test.json"
        self.assert_refused(str(focusblox(self.dir)), str(target), target=target)

    def test_refuses_wrong_number_of_heikel(self):
        heikel_file = write_json(self.dir, "h.json", heikel(99))
        target = Path(self.dir) / "out.json"
        self.assert_refused(str(focusblox(self.dir)), str(target), "--heikel", str(heikel_file), target=target)

    def test_refuses_duplicate_id(self):
        entries = heikel(100)
        entries[1]["id"] = entries[0]["id"]
        heikel_file = write_json(self.dir, "h.json", entries)
        target = Path(self.dir) / "out.json"
        self.assert_refused(str(focusblox(self.dir)), str(target), "--heikel", str(heikel_file), target=target)

    def test_refuses_id_without_known_prefix(self):
        heikel_file = write_json(self.dir, "h.json", heikel(100, prefix="xx-"))
        target = Path(self.dir) / "out.json"
        self.assert_refused(str(focusblox(self.dir)), str(target), "--heikel", str(heikel_file), target=target)

    def test_refuses_empty_alltag(self):
        target = Path(self.dir) / "out.json"
        proc = run_script("build", str(focusblox(self.dir, sentences=[])), str(target))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("guardrail_corpus:", proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertFalse(target.exists(), "Zieldatei darf nicht angelegt sein")


class CountTests(unittest.TestCase):
    def count(self, results):
        with tempfile.TemporaryDirectory() as d:
            path = write_json(d, "r.json", {"results": results})
            proc = run_script("count", str(path))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return int(proc.stdout.strip())

    def test_counts_success_guardrail_and_refusal_only(self):
        self.assertEqual(self.count([
            result("a", 0),
            result("a", 1, kind="guardrail", error="x"),
            result("b", 0, kind="refusal", error="x"),
            result("b", 1, kind="rateLimited", error="x"),
            result("c", 0, kind="timeout", error="x"),
        ]), 3)

    def test_duplicate_of_entry_and_run_counts_once(self):
        self.assertEqual(self.count([
            result("a", 0, kind="rateLimited", error="x"),
            result("a", 0),
            result("a", 0),
        ]), 1)

    def test_missing_run_index_is_run_zero(self):
        self.assertEqual(self.count([{"entryID": "a"}, {"entryID": "a"}]), 1)


class LabGuardrailCommandTests(unittest.TestCase):
    def test_dry_run_reports_and_touches_no_device(self):
        with tempfile.TemporaryDirectory() as d:
            fake = Path(d) / "bin"
            fake.mkdir()
            calls = Path(d) / "calls.txt"
            xcrun = fake / "xcrun"
            xcrun.write_text(f'#!/bin/bash\necho "$@" >> "{calls}"\nexit 1\n')
            xcrun.chmod(0o755)
            env = dict(os.environ, PATH=f"{fake}:{os.environ['PATH']}", TMPDIR=d + "/",
                       LOOSEENDS_FOCUSBLOX_CORPUS=str(focusblox(d)))
            proc = subprocess.run(["bash", str(SIM), "lab-guardrail", "--dry-run"],
                                  capture_output=True, text=True, env=env, cwd=ROOT, timeout=120)
            out = proc.stdout + proc.stderr
            self.assertEqual(proc.returncode, 0, out)
            self.assertIn("206", out)  # (100 + 3) × 2 Aufrufe
            self.assertIn("entsperrt", out)
            self.assertFalse(calls.exists(), "xcrun/devicectl darf im Trockenlauf nie laufen")
            for s in SENTENCES:
                self.assertNotIn(s, out)
            built = Path(d) / "loose-ends-71-guardrails" / "guardrail-geraet.json"
            self.assertTrue(built.exists())

    def test_bash_syntax_is_valid(self):
        proc = subprocess.run(["bash", "-n", str(SIM)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)


class CommandTextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = SIM.read_text()
        match = re.search(r"^cmd_lab_guardrail\(\) \{\n(.*?)^\}\n", text, re.S | re.M)
        assert match, "cmd_lab_guardrail fehlt in sim.sh"
        cls.body = match.group(1)

    def test_no_uninstall_and_only_lab_bundle(self):
        self.assertNotIn("device uninstall", self.body)
        self.assertNotIn("com.henning.looseends", self.body)
        self.assertIn('"$LAB_BUNDLE"', self.body)

    def test_runner_arguments(self):
        for arg in ("--count-failures", "--runs 2", "--result guardrail-iphone", "--exit-when-done",
                    "--measure", "--corpus guardrail-geraet"):
            self.assertIn(arg, self.body)

    def test_copy_to_targets_documents(self):
        self.assertIn("device copy to", self.body)
        self.assertIn('--domain-identifier "$LAB_BUNDLE"', self.body)
        self.assertIn("--destination Documents/guardrail-geraet.json", self.body)

    def test_output_locations(self):
        self.assertIn("docs/artifacts/71-guardrails/", self.body)
        self.assertIn("${TMPDIR", self.body)
        for path in re.findall(r"(?:/|\")(docs/[A-Za-z0-9_./-]+)", self.body):
            self.assertTrue(path.startswith("docs/artifacts/71-guardrails/"), path)

    def test_stale_result_is_removed_before_the_slices(self):
        self.assertIn('rm -f "$result"', self.body)
        self.assertLess(self.body.index('rm -f "$result"'), self.body.index("lab_guardrail_slices"))

    def test_existing_raw_data_survives_until_report_succeeds(self):
        self.assertNotIn('rm -f "$raw"', self.body)
        self.assertIn('TEST_RUNNER_LOOSEENDS_GUARDRAIL_OUT="$scratch/iphone-rohdaten.json"', self.body)
        move = self.body.index('mv "$scratch/iphone-rohdaten.json" "$raw"')
        self.assertLess(self.body.index("cmd_sim_unit IphoneGuardrailReportTests"), move)
        self.assertLess(self.body.index('[ -s "$scratch/iphone-rohdaten.json" ]'), move)

    def test_require_device_comes_after_the_announcement(self):
        self.assertIn("require_device", self.body)
        self.assertIn("entsperrt", self.body)
        self.assertLess(self.body.index("entsperrt"), self.body.index("require_device"))
        self.assertLess(self.body.index("--dry-run"), self.body.index("require_device"))


if __name__ == "__main__":
    unittest.main()
