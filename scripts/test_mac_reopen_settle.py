"""Tests für #978: Wiederöffnungstests des Menüleisten-Panels, Gegenprobe am Quelltext.

v5 (nach der Halteprobe v4, Lauf 45602877961: 1,0 s Halten schloss 20/20, 0,1 s 0/20): Überall, wo der Test das
Menüleistensymbol klickt (`openPanel`, beide Nutzerarme), klickt er wie ein Mensch kurz, 0,1 s, über einen Helfer
`shortClick` mit `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate. Keine Wiederholung, jeder
Fehlschlag hart rot. Die Klickwege aus v1 (`waitForFrontmostSettled`) und v3 (`frontmostRootClick`) und die
Rückfall-Regel entfallen. Kontrollarm und Halteprobe bleiben hinter ihren Umgebungsvariablen.

Aufruf: python3 scripts/test_mac_reopen_settle.py
Die CI fährt die Datei mit `unittest discover -s scripts -p 'test_*.py'`.

Die Mac-UI-Tests laufen nur in der CI; ihren Lauf belegen der Nachweislauf und die Pflichtläufe (Spec AC-7, AC-8).
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


def new_format_click(clicked_at: float, opened: bool) -> str:
    """So schreibt `assertSymbolOpensPanelWithOneClick` ab v5: kurzer Klick, kein Verlauf der vordersten App."""
    return (
        f"click: {clicked_at:.3f} (seconds since 1970)\n"
        "how: user: short click 0.1 s\n"
        "Attributes: Application, pid: 4711, label: 'Loose Ends'\n"
        "click duration: 0.142 s\n"
        f"after: {3.4 if opened else 10.02:.2f} s, panel {'open' if opened else 'not open'}\n"
    )


class ShortClickSourceTests(unittest.TestCase):
    """Spec AC-2, AC-3, AC-6: der Testquelltext. Kommentare zählen nicht."""

    def setUp(self):
        self.raw = GALLERY_TESTS.read_text()
        self.text = strip_comments(self.raw)
        self.helper = strip_comments(function_body(self.raw, "assertSymbolOpensPanelWithOneClick"))
        self.short = strip_comments(function_body(self.raw, "shortClick"))

    def test_exactly_one_short_click_helper(self):
        self.assertEqual(len(re.findall(r"func shortClick\(", self.text)), 1, "genau ein Helfer shortClick")

    def test_helper_clicks_middle_for_0_1_s_onto_same_coordinate(self):
        self.assertIn("coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))", self.short)
        match = re.search(r"(\w+)\.click\(forDuration: 0\.1, thenDragTo: (\w+)\)", self.short)
        self.assertIsNotNone(match, "click(forDuration: 0.1, thenDragTo:) fehlt")
        self.assertEqual(match.group(1), match.group(2), "Ziehen auf dieselbe Koordinate")
        self.assertIn('"user: short click 0.1 s"', self.short)

    def test_helper_has_no_fallback_and_no_retry(self):
        self.assertNotIn("statusItem.click()", self.short)
        self.assertNotIn(".click()", self.short)
        self.assertFalse(re.search(r"\b(for|while|repeat)\b", self.short), "keine Wiederholung")

    def test_open_panel_uses_short_click(self):
        body = strip_comments(function_body(self.raw, "openPanel"))
        self.assertEqual(len(re.findall(r"\bshortClick\(", body)), 1, "openPanel klickt genau einmal kurz")
        self.assertNotIn("statusItem.click()", body)

    def test_user_arms_use_short_click_exactly_once(self):
        self.assertEqual(len(re.findall(r"\bshortClick\(", self.helper)), 1, "genau ein Nutzerklick")
        self.assertEqual(len(re.findall(r"\bclick\(statusItem\)", self.helper)), 1, "Kontrollarm: sein eigener Klick")
        self.assertFalse(re.search(r"\b(for|while|repeat)\b", self.helper), "keine Wiederholung im Klickweg")
        for label in ("reopen-return", "reopen-open-app"):
            self.assertIn(f'assertSymbolOpensPanelWithOneClick(app, label: "{label}")', self.text)

    def test_v1_v3_paths_and_fallback_rule_gone(self):
        for gone in ("frontmostRootClick", "waitForFrontmostSettled", "fallback", "frontmost menu bar"):
            self.assertNotIn(gone, self.text, f"darf nicht stehen: {gone}")

    def test_hard_failure_without_second_try(self):
        self.assertFalse("XCTExpectFailure" in self.text)
        self.assertFalse("continueAfterFailure = true" in self.text)
        self.assertRegex(self.helper, r'buttons\["menuBarOpenApp"\]\.waitForExistence\(timeout: 10\)')
        self.assertRegex(self.helper, r'menuBarOpenApp"\]\.exists', "nach 3 s noch vorhanden")
        self.assertRegex(self.helper, r"XCTAssertTrue\(opened")

    def test_attachment_first_click_last_after(self):
        literal = re.search(r'XCTAttachment\(string: """\n(.*?)"""', self.helper, re.S)
        self.assertIsNotNone(literal, "Anhangtext fehlt")
        lines = [line.strip() for line in literal.group(1).splitlines() if line.strip()]
        self.assertTrue(lines[0].startswith("click:"))
        self.assertTrue(any(line.startswith("how:") for line in lines))
        self.assertTrue(lines[-1].startswith("after:"))

    def test_control_arm_and_hold_probe_stay_behind_env(self):
        control = function_body(self.raw, "testMenuBarReopensAfterReturnWithControlClick")
        self.assertIn("LE_PANEL_CONTROL_ARM", control)
        self.assertIn("XCTSkip(", control)
        self.assertIn("click: Self.coordinateClick", control)
        probe = function_body(self.raw, "testHoldDurationProbe")
        self.assertIn("LE_PANEL_HOLD_PROBE", probe)
        self.assertIn("XCTSkip(", probe)


class NewFormatSummaryTests(unittest.TestCase):
    """Der Auswerter liest das v5-Anhangformat; `how` ist die Kategorie short-click."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_parse_click_new_format(self):
        self.assertEqual(self.summary.parse_click(new_format_click(1763900000.5, True)), (1763900000.5, True))
        self.assertEqual(self.summary.parse_click(new_format_click(1763900001.25, False)),
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
        self.assertEqual(self.summary.how_of(new_format_click(1.0, True)), "short-click")


if __name__ == "__main__":
    unittest.main(verbosity=2)
