"""Tests für #978 Schnitt 3: Wiederöffnungstests warten den App-Wechsel ab, prüfen eine Haltezeit, ⌘W-Arm hart.

Aufruf: python3 scripts/test_mac_reopen_settle.py
Die CI fährt die Datei mit `unittest discover -s scripts -p 'test_*.py'`.

Die Mac-UI-Tests laufen nur in der CI; ihren Lauf belegen die Pflichtläufe und der Wiederholungslauf (AC-5, AC-6).
Hier steht die Gegenprobe am Quelltext von `LooseEndsUITests/MacGalleryTests.swift` (AC-1 bis AC-4, AC-7) und die
Probe, dass `scripts/mac_panel_repeat_summary.py` das neue Anhangformat unverändert liest (AC-4).
"""
import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GALLERY_TESTS = ROOT / "LooseEndsUITests" / "MacGalleryTests.swift"
SCRIPT = ROOT / "scripts" / "mac_panel_repeat_summary.py"


def load_summary():
    spec = importlib.util.spec_from_file_location("mac_panel_repeat_summary", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def function_body(text: str, name: str) -> str:
    """Rumpf einer Funktion der Klasse (Einrückung 4, Ende an der ersten `    }`-Zeile)."""
    match = re.search(rf"func {name}\(.*?\n    \}}\n", text, re.S)
    if match is None:
        raise AssertionError(f"fehlt: func {name}")
    return match.group(0)


def new_format_click(clicked_at: float, opened: bool, settled: bool = True) -> str:
    """So soll `assertSymbolOpensPanelWithOneClick` ab Schnitt 3 schreiben: Verlauf vor der letzten Zeile."""
    history = ("front 0.00 s com.apple.dt.xctest.tool\nfront 0.42 s com.henning.looseends\nsettled after 1.42 s\n"
               if settled else "front 0.00 s com.apple.dt.xctest.tool\ntimeout after 10 s\n")
    return (
        f"click: {clicked_at:.3f} (seconds since 1970)\n"
        "how: user: statusItem.click()\n"
        f"{history}"
        "Attributes: Application, pid: 4711, label: 'Loose Ends'\n"
        f"after: {3.4 if opened else 10.02:.2f} s, panel {'open' if opened else 'not open'}\n"
    )


class SettleSourceTests(unittest.TestCase):
    def assertRegex(self, text, pattern, msg=None):
        self.assertTrue(re.search(pattern, text), msg or f"kein Treffer: {pattern}")

    def assertNotRegex(self, text, pattern, msg=None):
        self.assertFalse(re.search(pattern, text), msg or f"darf nicht passen: {pattern}")
    """AC-1 bis AC-3, AC-7: der Testquelltext."""

    def setUp(self):
        self.text = GALLERY_TESTS.read_text()
        self.helper = function_body(self.text, "assertSymbolOpensPanelWithOneClick")

    def test_ac1_no_expected_failure_left(self):
        self.assertFalse("XCTExpectFailure" in self.text, "darf nicht stehen: XCTExpectFailure")
        self.assertFalse("continueAfterFailure = true" in self.text, "darf nicht stehen: continueAfterFailure = true")

    def test_ac1_open_app_arm_calls_helper_directly(self):
        arm = function_body(self.text, "testMenuBarReopensAfterOpenAppWithOneClick")
        self.assertIn('assertSymbolOpensPanelWithOneClick(app, label: "reopen-open-app")', arm)
        self.assertIn("app.terminate()", arm)

    def test_ac2_settle_helper_reads_frontmost_app(self):
        self.assertRegex(self.text, r"(?m)^import AppKit$")
        settle = function_body(self.text, "waitForFrontmostSettled")
        self.assertIn("NSWorkspace.shared.frontmostApplication", settle)
        self.assertIn("bundleIdentifier", settle)
        self.assertRegex(settle, r"0\.1\b", "Abfrage alle 0,1 s")
        self.assertRegex(settle, r"\b1(\.0)?\b", "1 s unverändert")
        self.assertRegex(settle, r"\b10(\.0)?\b", "Obergrenze 10 s")
        self.assertIn("settled after", settle)
        self.assertIn("timeout after", settle)

    def test_ac2_order_symbol_settle_click_panel_hold_attachment_assert(self):
        steps = [
            ("Symbol existiert", r"statusItem\.waitForExistence\(timeout: 10\)"),
            ("ruhig warten", r"waitForFrontmostSettled\("),
            ("Klick", r"statusItem\.click\(\)"),
            ("Panel binnen 10 s", r'buttons\["menuBarOpenApp"\]\.waitForExistence\(timeout: 10\)'),
            ("Haltezeit 3 s", r"\b3(\.0)?\b"),
            ("Anhang", r"add\(note\)"),
            ("harte Assertion", r"XCTAssertTrue\("),
        ]
        position = 0
        for name, pattern in steps:
            match = re.compile(pattern).search(self.helper, position)
            self.assertIsNotNone(match, f"Schritt fehlt oder steht falsch: {name}")
            position = match.end()

    def test_ac2_exactly_one_click_no_retry(self):
        # Der Text "user: statusItem.click()" im Anhang zählt nicht, nur der Aufruf.
        self.assertEqual(len(re.findall(r'statusItem\.click\(\)(?!")', self.helper)), 1, "genau ein Klick")
        self.assertEqual(len(re.findall(r"\bclick\(statusItem\)", self.helper)), 1)
        self.assertNotRegex(self.helper, r"\b(for|while|repeat)\b", "keine Wiederholung im Klickweg")

    def test_ac2_hold_checks_panel_still_there(self):
        self.assertRegex(self.helper, r'menuBarOpenApp"\]\.exists', "nach 3 s noch vorhanden")

    def test_ac3_all_three_arms_use_helper(self):
        for label in ("reopen-return", "reopen-open-app", "reopen-return-control"):
            self.assertIn(f'assertSymbolOpensPanelWithOneClick(app, label: "{label}"', self.text)
        control = function_body(self.text, "testMenuBarReopensAfterReturnWithControlClick")
        self.assertIn("LE_PANEL_CONTROL_ARM", control)
        self.assertIn("XCTSkip(", control)

    def test_ac4_after_line_is_last_and_history_before_it(self):
        literal = re.search(r'XCTAttachment\(string: """\n(.*?)"""', self.helper, re.S)
        self.assertIsNotNone(literal, "Anhangtext fehlt")
        lines = [line.strip() for line in literal.group(1).splitlines() if line.strip()]
        self.assertTrue(lines[0].startswith("click:"), "erste Zeile click:")
        self.assertTrue(lines[-1].startswith("after:"), "letzte Zeile after: … panel open|not open")
        self.assertTrue(any(line.startswith("how:") for line in lines))
        history = [i for i, line in enumerate(lines) if "settle" in line or "front" in line]
        self.assertTrue(history, "Verlauf der vordersten App fehlt im Anhang")
        self.assertLess(max(history), len(lines) - 1)


class NewFormatSummaryTests(unittest.TestCase):
    """AC-4: das unveränderte Skript liest das neue Format."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_parse_click_new_format(self):
        self.assertEqual(self.summary.parse_click(new_format_click(1763900000.5, True)), (1763900000.5, True))
        self.assertEqual(self.summary.parse_click(new_format_click(1763900001.25, False, settled=False)),
                         (1763900001.25, False))

    def test_counts_new_format(self):
        folder = Path(self.tmp.name) / "raw"
        folder.mkdir()
        entries = []
        for index, (label, opened) in enumerate([("reopen-return", True), ("reopen-return", False),
                                                 ("reopen-open-app", True)]):
            name = f"{index:04d}-click.txt"
            (folder / name).write_text(new_format_click(float(index), opened))
            entries.append({"testIdentifier": f"MacGalleryTests/t{index}()", "attachments": [
                {"exportedFileName": name, "suggestedHumanReadableName": f"mac-gallery-{label}-click_0_{index}.txt"}]})
        (folder / "manifest.json").write_text(json.dumps(entries))
        counts = self.summary.count_arms([folder])
        self.assertEqual(counts["return"], {"n": 2, "fails": 1, "rate": 0.5})
        self.assertEqual(counts["open-app"], {"n": 1, "fails": 0, "rate": 0.0})


if __name__ == "__main__":
    unittest.main(verbosity=2)
