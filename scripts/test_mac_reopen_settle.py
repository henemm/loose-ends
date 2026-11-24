"""Tests für #978 Schnitt 3: Wiederöffnungstests warten den App-Wechsel ab, prüfen eine Haltezeit, ⌘W-Arm hart.

v3 (nach v2-Galerielauf 45464097119): Wurzel ist die Menüleiste der vordersten App (`menuBars`), nur mit Rahmen bei
y = 0; Rückfälle mit eigenem Text; ein Rückfall bei fremder vorderster App macht den Nutzerarm rot.

v2 (nach Galerie-Versuch 3): Der Nutzerklick läuft über eine `XCUICoordinate`, deren Wurzel die vorderste App ist
(`frontmostRootClick`), damit `click()` Loose Ends nicht aktiviert; Rückfall `statusItem.click()`, Klickdauer im Anhang.

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


def strip_comments(text: str) -> str:
    return re.sub(r"//.*$", "", text, flags=re.M)


def new_format_click(clicked_at: float, opened: bool, settled: bool = True) -> str:
    """So soll `assertSymbolOpensPanelWithOneClick` ab Schnitt 3 schreiben: Verlauf vor der letzten Zeile."""
    history = ("front 0.00 s com.apple.dt.xctest.tool\nfront 0.42 s com.henning.looseends\nsettled after 1.42 s\n"
               if settled else "front 0.00 s com.apple.dt.xctest.tool\ntimeout after 10 s\n")
    return (
        f"click: {clicked_at:.3f} (seconds since 1970)\n"
        "how: user: frontmost menu bar com.apple.finder\n"
        "click duration: 0.412 s\n"
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
            ("Klick über die vorderste App", r"frontmostRootClick\("),
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
        # Nutzerarme: genau ein Aufruf des Klickwegs; Kontrollarm: genau ein Aufruf seines eigenen Klicks.
        self.assertEqual(len(re.findall(r"\bfrontmostRootClick\(", self.helper)), 1, "genau ein Nutzerklick")
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
        self.assertIn("click: Self.coordinateClick", control, "Kontrollarm unverändert (AC-4 v2)")

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


class FrontmostRootClickTests(unittest.TestCase):
    """v3 AC-1 bis AC-3: Klick über die Menüleiste der vordersten App als Koordinatenwurzel, Rückfälle mit eigenem
    Text, ein stiller Rückfall bei fremder vorderster App färbt den Nutzerarm rot. Kommentare zählen nicht."""

    def setUp(self):
        self.text = GALLERY_TESTS.read_text()
        self.helper = strip_comments(function_body(self.text, "assertSymbolOpensPanelWithOneClick"))
        self.root_click = strip_comments(function_body(self.text, "frontmostRootClick"))

    def test_ac1_root_is_menu_bar_of_frontmost_app(self):
        self.assertIn("XCUIApplication(bundleIdentifier:", self.root_click)
        self.assertRegex(self.root_click, r"\.menuBars\.element\(boundBy: 0\)", "Wurzel = erste Menüleiste")
        self.assertIn("coordinate(withNormalizedOffset: .zero)", self.root_click)
        self.assertIn(".withOffset(", self.root_click)

    def test_ac1_root_only_with_frame_at_top(self):
        self.assertIn(".isEmpty", self.root_click, "leerer Menüleistenrahmen → Rückfall")
        self.assertRegex(self.root_click, r"\.(minY|origin\.y)\s*(!=|==)\s*0", "Ursprung y = 0 geprüft")

    def test_ac1_offset_is_item_middle_minus_menu_bar_origin(self):
        self.assertRegex(self.root_click, r"statusItem\.frame", "Offset aus statusItem.frame")
        for name in ("midX", "midY"):
            self.assertIn(name, self.root_click, f"Mitte des Symbols: {name}")
        self.assertRegex(self.root_click, r"\.(origin\.x|minX)\b", "Ursprung der Menüleiste x")
        self.assertRegex(self.root_click, r"\.(origin\.y|minY)\b", "Ursprung der Menüleiste y")

    def test_ac1_no_root_from_app_frame_any_more(self):
        self.assertNotRegex(self.root_click, r"\broot\.frame\b", "v2-Wurzel (App-Rahmen) ist widerlegt")
        self.assertNotIn("empty frame", self.root_click, "v2-Rückfalltext entfällt")
        self.assertNotIn("user: frontmost root ", self.root_click, "v2-how-Text entfällt")

    def test_ac2_three_how_texts(self):
        self.assertIn('"user: frontmost menu bar \\(', self.root_click)
        self.assertIn('"user: statusItem.click() fallback (frontmost com.henning.looseends)"', self.root_click)
        self.assertIn(", no menu bar frame)", self.root_click)
        self.assertIn("user: statusItem.click() fallback (frontmost \\(", self.root_click)

    def test_ac2_fallback_is_statusitem_click_once_no_retry(self):
        self.assertIn("statusItem.click()", self.root_click)
        self.assertNotRegex(self.root_click, r"\b(for|while|repeat)\b", "keine Wiederholung im Klick")
        code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', self.root_click)
        self.assertEqual(len(re.findall(r"\.click\(\)", code)),
                         len(re.findall(r"\breturn\b", code)), "je Weg genau ein Klick")

    def test_ac2_user_arms_click_through_root_control_arm_its_own(self):
        self.assertTrue(re.search(r"if let click \{[^}]*click\(statusItem\)[^}]*\} else \{[^}]*frontmostRootClick\(",
                                  self.helper, re.S), "Nutzerarme über frontmostRootClick, Kontrollarm über click")

    def test_ac2_click_duration_line_before_after_line(self):
        literal = re.search(r'XCTAttachment\(string: """\n(.*?)"""', self.helper, re.S)
        self.assertIsNotNone(literal, "Anhangtext fehlt")
        lines = [line.strip() for line in literal.group(1).splitlines() if line.strip()]
        duration = [i for i, line in enumerate(lines) if line.startswith("click duration:")]
        self.assertTrue(duration, "Zeile „click duration: <s> s“ fehlt")
        self.assertTrue(lines[-1].startswith("after:"), "letzte Zeile bleibt after: … panel open|not open")
        self.assertLess(duration[0], len(lines) - 1)

    def test_ac3_fallback_with_foreign_frontmost_fails_with_how(self):
        """Lehre aus v2: ein stiller Rückfall bei fremder vorderster App wird nie grün. Die Meldung nennt `how`."""
        self.assertRegex(self.helper, r"fallback", "Rückfall wird im Helfer erkannt")
        self.assertIn('"com.henning.looseends"', self.helper, "Loose Ends vorn bleibt zulässig")
        self.assertRegex(self.helper, r"XCT(Fail|AssertFalse|AssertTrue)\([^\n]*\\\(how\)",
                         "harte Assertion mit how in der Meldung")

    def test_ac3_hard_check_only_for_user_arms(self):
        self.assertRegex(self.helper, r"click\s*==\s*nil", "Kontrollarm bleibt von der Rückfall-Regel unberührt")


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
