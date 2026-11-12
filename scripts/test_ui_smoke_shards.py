"""Tests für die Aufteilung des UI-Smoke-Jobs auf vier Teile (#910).

Aufruf: python3 scripts/test_ui_smoke_shards.py
Schnittstelle von `ui_smoke_shards.py`: `split(tests_dir, n)` gibt n Listen von Klassennamen,
`weights(tests_dir)` Klasse → Gewicht. Die Klassen liest der Test unabhängig per Regex.
"""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
UI_TESTS = ROOT / "LooseEndsUITests"
CI = ROOT / ".github" / "workflows" / "ci.yml"
SCRIPT = ROOT / "scripts" / "ui_smoke_shards.py"
CLASS = re.compile(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase", re.MULTILINE)
PHOTO = ("DesignGalleryTests", "StoreScreenshotsTests")


def _module():
    sys.path.insert(0, str(ROOT / "scripts"))
    try:
        import ui_smoke_shards
    finally:
        sys.path.pop(0)
    return ui_smoke_shards


def _classes_on_disk(directory: Path) -> set:
    found = set()
    for path in directory.glob("*.swift"):  # ohne Unterordner Watch/
        found |= set(CLASS.findall(path.read_text(encoding="utf-8")))
    return found


class ShardTests(unittest.TestCase):
    def test_ac1_every_class_exactly_once(self):
        shards = _module().split(UI_TESTS, 4)
        flat = [name for shard in shards for name in shard]
        self.assertEqual(len(flat), len(set(flat)), "eine Klasse liegt doppelt")
        self.assertEqual(set(flat), _classes_on_disk(UI_TESTS))
        self.assertNotIn("WatchSmokeTests", flat)  # Watch/ gehört nicht dazu

    def test_ac2_no_shard_empty_and_photo_classes_apart(self):
        shards = _module().split(UI_TESTS, 4)
        self.assertEqual(len(shards), 4)
        self.assertTrue(all(shards), "ein Teil ist leer")
        where = {name: i for i, shard in enumerate(shards) for name in shard}
        self.assertNotEqual(where[PHOTO[0]], where[PHOTO[1]])

    def test_ac3_deterministic_and_new_class_is_assigned(self):
        mod = _module()
        self.assertEqual(mod.split(UI_TESTS, 4), mod.split(UI_TESTS, 4))
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "A.swift").write_text(
                "final class AlphaTests: XCTestCase {\n func testOne() {}\n func testTwo() {}\n}\n")
            Path(tmp, "B.swift").write_text("final class BetaTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "C.swift").write_text("final class NewTests: XCTestCase {\n func testNew() {}\n}\n")
            flat = [name for shard in mod.split(Path(tmp), 2) for name in shard]
            self.assertEqual(sorted(flat), ["AlphaTests", "BetaTests", "NewTests"])

    def test_ac4_greedy_quality(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        shards = mod.split(UI_TESTS, 4)
        sums = [sum(weight[name] for name in shard) for shard in shards]
        average = sum(sums) / len(sums)
        self.assertLessEqual(max(sums), average + max(weight.values()))

    def test_f001_attribute_and_own_base_class_are_found(self):
        mod = _module()
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "A.swift").write_text(
                "@MainActor final class AttributedTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "Base.swift").write_text(
                "class BaseUITestCase: XCTestCase {\n func launch() {}\n override class var defaultTestSuite: XCTestSuite"
                " { super.defaultTestSuite }\n}\n")
            Path(tmp, "Sub.swift").write_text(
                "final class SubTests: BaseUITestCase {\n func testA() {}\n func testB() {}\n}\n"
                "final class Helper: NSObject {\n func testNot() {}\n}\n")
            self.assertEqual(mod.weights(Path(tmp)), {"AttributedTests": 1, "BaseUITestCase": 0, "SubTests": 2})

    def test_f002_only_skips_weight_zero_and_is_never_empty(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        for entry in mod.matrix(UI_TESTS, 4)["include"]:
            self.assertTrue(entry["only"], f"Teil {entry['shard']}: only ist leer")
            named = re.findall(r"-only-testing:LooseEndsUITests/(\w+)", entry["only"])
            self.assertTrue(named)
            self.assertFalse([name for name in named if weight[name] == 0], "Gewicht-0-Klasse in -only-testing")
            self.assertEqual(set(named), {name for name in entry["classes"].split() if weight[name] > 0})

    def test_f002_empty_only_is_an_error(self):
        mod = _module()
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "A.swift").write_text("final class AlphaTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "M.swift").write_text("#if os(macOS)\nfinal class MacTests: XCTestCase {\n func testM() {}\n}\n#endif\n")
            with self.assertRaises(SystemExit) as raised:
                mod.matrix(Path(tmp), 2)
            self.assertNotIn(raised.exception.code, (0, None))

    def test_cli_prints_matrix_json(self):
        out = subprocess.run([sys.executable, str(SCRIPT), "4"], capture_output=True, text=True, check=True)
        import json
        matrix = json.loads(out.stdout)
        self.assertEqual(len(matrix["include"]), 4)
        for entry in matrix["include"]:
            self.assertIn("shard", entry)
            self.assertIn("-only-testing:LooseEndsUITests/", entry["only"])


class WorkflowTests(unittest.TestCase):
    def test_ac5_collector_job_keeps_the_protected_name(self):
        jobs = yaml.safe_load(CI.read_text(encoding="utf-8"))["jobs"]
        named = {key: job for key, job in jobs.items() if job.get("name") == "UI Smoke (iOS Simulator)"}
        self.assertEqual(len(named), 1, "genau ein Job trägt den geschützten Namen")
        job = next(iter(named.values()))
        self.assertEqual(job["if"], "always()")
        self.assertEqual(job["needs"], ["ui-smoke-shard"])
        shard = jobs["ui-smoke-shard"]
        self.assertFalse(shard["strategy"]["fail-fast"])


if __name__ == "__main__":
    unittest.main()
