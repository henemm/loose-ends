"""Tests für die Aufteilung des UI-Smoke-Jobs auf sechs Teile (#910, #939).

Aufruf: python3 scripts/test_ui_smoke_shards.py
Schnittstelle von `ui_smoke_shards.py`: `weights(tests_dir)` Klasse → Gewicht, `methods(tests_dir)` Klasse → Namen
ihrer `func test…`, `units(tests_dir, n)` Einheit → Gewicht (`Klasse` oder, bei einer Klasse über der Zielgröße,
`Klasse/test` mit Gewicht 1), `split(tests_dir, n)` n Listen von Einheiten, `matrix(tests_dir, n)` das JSON der Matrix.
Klassen und Methoden liest der Test unabhängig per Regex.
"""
import json
import math
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
ANY_CLASS = re.compile(r"^[ \t]*(?:@\w+\s+)*(?:final\s+)?class\s+(?!(?:var|func|let)\b)(\w+)\s*:", re.MULTILINE)
METHOD = re.compile(r"^\s*(?:@\w+\s+)*func\s+(test\w*)\s*\(", re.MULTILINE)
ONLY = re.compile(r"-only-testing:LooseEndsUITests/(\w+)(?:/(\w+))?")
PHOTO = ("DesignGalleryTests", "StoreScreenshotsTests")
N = 6


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


def _methods_on_disk(directory: Path) -> dict:
    """Klasse → Menge ihrer test-Methoden, von Klassenkopf zu Klassenkopf derselben Datei."""
    found = {}
    for path in directory.glob("*.swift"):
        text = path.read_text(encoding="utf-8")
        heads = list(ANY_CLASS.finditer(text))
        for i, head in enumerate(heads):
            end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
            found[head.group(1)] = set(METHOD.findall(text, head.end(), end))
    return found


def _class_of(unit: str) -> str:
    return unit.split("/")[0]


def _load(unit: str, weight: dict) -> int:
    return 1 if "/" in unit else weight[unit]


class ShardTests(unittest.TestCase):
    def test_ac1_every_method_exactly_once(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        on_disk = _methods_on_disk(UI_TESTS)
        flat = [unit for shard in mod.split(UI_TESTS, N) for unit in shard]
        self.assertEqual(len(flat), len(set(flat)), "eine Einheit liegt doppelt")
        self.assertEqual({_class_of(unit) for unit in flat}, _classes_on_disk(UI_TESTS))
        self.assertNotIn("WatchSmokeTests", {_class_of(unit) for unit in flat})  # Watch/ gehört nicht dazu
        for name, methods in on_disk.items():
            if weight.get(name, 0) == 0 or name in PHOTO:
                continue
            whole = name in flat
            pieces = [unit.split("/")[1] for unit in flat if unit.startswith(name + "/")]
            self.assertFalse(whole and pieces, f"{name} steht ganz und zerlegt zugleich")
            covered = sorted(methods) if whole else sorted(pieces)
            self.assertEqual(covered, sorted(methods), f"{name}: Methoden fehlen oder doppelt")

    def test_ac1_oversized_class_is_split_by_method(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        target = math.ceil(sum(weight.values()) / N)
        units = mod.units(UI_TESTS, N)
        self.assertGreater(weight["CaptureSmokeTests"], target)
        self.assertNotIn("CaptureSmokeTests", units)
        pieces = {unit for unit in units if unit.startswith("CaptureSmokeTests/")}
        self.assertEqual({p.split("/")[1] for p in pieces}, _methods_on_disk(UI_TESTS)["CaptureSmokeTests"])
        self.assertTrue(all(units[p] == 1 for p in pieces))
        self.assertEqual(sorted(mod.methods(UI_TESTS)["CaptureSmokeTests"]),
                         sorted(_methods_on_disk(UI_TESTS)["CaptureSmokeTests"]))

    def test_ac2_no_shard_empty_and_photo_classes_apart(self):
        shards = _module().split(UI_TESTS, N)
        self.assertEqual(len(shards), N)
        self.assertTrue(all(shards), "ein Teil ist leer")
        where = {unit: i for i, shard in enumerate(shards) for unit in shard}
        self.assertNotEqual(where[PHOTO[0]], where[PHOTO[1]])

    def test_ac3_load_bound_and_below_today(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        units = mod.units(UI_TESTS, N)
        target = math.ceil(sum(weight.values()) / N)
        biggest_whole = max(w for unit, w in units.items() if "/" not in unit)
        sums = [sum(_load(unit, weight) for unit in shard) for shard in mod.split(UI_TESTS, N)]
        self.assertLessEqual(max(sums), target + biggest_whole, sums)
        self.assertLess(max(sums), 31, sums)

    def test_ac4_deterministic_and_new_class_is_assigned(self):
        mod = _module()
        self.assertEqual(mod.split(UI_TESTS, N), mod.split(UI_TESTS, N))
        self.assertEqual(mod.matrix(UI_TESTS, N), mod.matrix(UI_TESTS, N))
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "A.swift").write_text(
                "final class AlphaTests: XCTestCase {\n func testOne() {}\n func testTwo() {}\n}\n")
            Path(tmp, "B.swift").write_text("final class BetaTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "C.swift").write_text("final class NewTests: XCTestCase {\n func testNew() {}\n}\n")
            flat = [unit for shard in mod.split(Path(tmp), 2) for unit in shard]
            self.assertEqual(sorted(_class_of(unit) for unit in flat), ["AlphaTests", "BetaTests", "NewTests"])

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
            self.assertEqual(mod.methods(Path(tmp))["SubTests"], ["testA", "testB"])

    def test_f002_only_skips_weight_zero_and_is_never_empty(self):
        mod = _module()
        weight = mod.weights(UI_TESTS)
        for entry in mod.matrix(UI_TESTS, N)["include"]:
            self.assertTrue(entry["only"], f"Teil {entry['shard']}: only ist leer")
            named = ONLY.findall(entry["only"])
            self.assertTrue(named)
            self.assertFalse([name for name, _ in named if weight[name] == 0], "Gewicht-0-Klasse in -only-testing")
            self.assertEqual({name for name, _ in named},
                             {name for name in entry["classes"].split() if weight[name] > 0})

    def test_f002_split_class_and_mac_class_in_temp_dir(self):
        mod = _module()
        with tempfile.TemporaryDirectory() as tmp:
            body = "".join(f" func test{c}() {{}}\n" for c in "ABCDEF")
            Path(tmp, "A.swift").write_text(f"final class AlphaTests: XCTestCase {{\n{body}}}\n")
            Path(tmp, "B.swift").write_text("final class BetaTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "M.swift").write_text("#if os(macOS)\nfinal class MacTests: XCTestCase {\n func testM() {}\n}\n#endif\n")
            include = mod.matrix(Path(tmp), 2)["include"]
            named = [pair for entry in include for pair in ONLY.findall(entry["only"])]
            self.assertTrue(all(entry["only"] for entry in include))
            self.assertNotIn("MacTests", {name for name, _ in named})
            self.assertNotIn(("AlphaTests", ""), named, "übergroße Klasse steht ganz in -only-testing")
            self.assertEqual(sorted(test for name, test in named if name == "AlphaTests"),
                             [f"test{c}" for c in "ABCDEF"])

    def test_f002_empty_only_is_an_error(self):
        mod = _module()
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "A.swift").write_text("final class AlphaTests: XCTestCase {\n func testOne() {}\n}\n")
            Path(tmp, "M.swift").write_text("#if os(macOS)\nfinal class MacTests: XCTestCase {\n func testM() {}\n}\n#endif\n")
            with self.assertRaises(SystemExit) as raised:
                mod.matrix(Path(tmp), 2)
            self.assertNotIn(raised.exception.code, (0, None))

    def test_cli_prints_matrix_json(self):
        out = subprocess.run([sys.executable, str(SCRIPT), str(N)], capture_output=True, text=True, check=True)
        matrix = json.loads(out.stdout)
        self.assertEqual(len(matrix["include"]), N)
        for entry in matrix["include"]:
            self.assertEqual(set(entry), {"shard", "classes", "only"})
            self.assertIn("-only-testing:LooseEndsUITests/", entry["only"])


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.jobs = yaml.safe_load(CI.read_text(encoding="utf-8"))["jobs"]

    def _step(self, job, name):
        steps = [step for step in self.jobs[job]["steps"] if step.get("name") == name]
        self.assertEqual(len(steps), 1, f"{job}: Schritt {name!r}")
        return steps[0]

    def test_ac5_collector_job_keeps_the_protected_name(self):
        named = {key: job for key, job in self.jobs.items() if job.get("name") == "UI Smoke (iOS Simulator)"}
        self.assertEqual(len(named), 1, "genau ein Job trägt den geschützten Namen")
        job = next(iter(named.values()))
        self.assertEqual(job["if"], "always()")
        self.assertEqual(job["needs"], ["ui-smoke-shard"])
        self.assertFalse(self.jobs["ui-smoke-shard"]["strategy"]["fail-fast"])

    def test_ac5_six_parts_and_time_limits(self):
        plan = next(step for step in self.jobs["ui-smoke-plan"]["steps"] if step.get("id") == "split")
        self.assertIn("python3 scripts/ui_smoke_shards.py 6", plan["run"])
        self.assertEqual(self.jobs["ui-smoke-shard"]["timeout-minutes"], 70)
        self.assertEqual(self._step("ui-smoke-shard", "Run UI smoke tests")["timeout-minutes"], 55)

    def test_ac5_uploads_do_not_fail_a_part(self):
        for name in ("Upload design gallery", "Upload UI test results"):
            self.assertIs(self._step("ui-smoke-shard", name).get("continue-on-error"), True, name)


if __name__ == "__main__":
    unittest.main()
