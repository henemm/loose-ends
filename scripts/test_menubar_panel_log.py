"""Tests für #978 Schnitt 1: Panel-Protokoll ernten (Test aktiv, App-Zeilen, CI-Schritt).

Aufruf: python3 scripts/test_menubar_panel_log.py
Prüft nur den Stand im Repo (Test, App-Code, ci.yml). Ob die Zeilen im echten Lauf ankommen und der
Job grün bleibt, zeigt nur der Job „Mac Gallery (macOS)“ (AC-2, AC-3).
"""
import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
TEST = ROOT / "LooseEndsUITests" / "MacGalleryTests.swift"
APP = ROOT / "LooseEnds" / "Mac" / "MenuBarCapture.swift"
CI = ROOT / ".github" / "workflows" / "ci.yml"
TEST_NAME = "testMenuBarReopensAfterOpenAppWithOneClick"
CATEGORY = 'category: "MenuBarPanel"'


def function_body(source, name):
    """Text der Swift-Funktion `name` bis zur schließenden Klammer auf gleicher Tiefe."""
    start = source.index(f"func {name}(")
    open_at = source.index("{", start)
    depth = 0
    for i in range(open_at, len(source)):
        depth += {"{": 1, "}": -1}.get(source[i], 0)
        if depth == 0:
            return source[open_at:i + 1]
    raise AssertionError(f"{name}: keine schließende Klammer")


def mac_gallery_steps():
    return yaml.safe_load(CI.read_text())["jobs"]["mac-gallery"]["steps"]


def panel_log_step():
    steps = [s for s in mac_gallery_steps() if "MenuBarPanel" in (s.get("run") or "")]
    if not steps:
        raise AssertionError("kein Schritt in mac-gallery liest die Kategorie MenuBarPanel")
    return steps[0]


def panel_log_upload():
    uploads = [s for s in mac_gallery_steps()
               if str(s.get("uses", "")).startswith("actions/upload-artifact")
               and (s.get("with") or {}).get("name") == "MacGalleryPanelLog"]
    if not uploads:
        raise AssertionError("kein Upload MacGalleryPanelLog in mac-gallery")
    return uploads[0]


class TestOpenAppArmIsHard(unittest.TestCase):
    """#978 S3, AC-1: der ⌘W-Arm ist hart, ohne erwarteten Fehler und ohne Weiterlaufen nach einem Fehler."""

    CHECK = "assertSymbolOpensPanelWithOneClick"

    def setUp(self):
        self.body = function_body(TEST.read_text(), TEST_NAME)

    def test_no_skip(self):
        self.assertNotIn("XCTSkip", self.body)

    def test_click_check_is_hard(self):
        self.assertNotIn("XCTExpectFailure", self.body)
        self.assertNotRegex(self.body, r"continueAfterFailure\s*=\s*true")
        self.assertIn(self.CHECK, self.body)

    def test_setup_stays_hard(self):
        """Aufbau (Open Loose Ends, ⌘W) steht vor der Klickprüfung."""
        self.assertIn(self.CHECK, self.body)
        before = self.body.split(self.CHECK, 1)[0]
        self.assertIn('"⌘W did not close the main window"', before)
        self.assertIn("menuBarOpenApp", before)


class AppWritesPanelLines(unittest.TestCase):
    """AC-3/AC-4: die App schreibt Notice-Zeilen der Kategorie MenuBarPanel, ohne Nutzerdaten."""

    def setUp(self):
        self.source = APP.read_text()

    def test_logger_category(self):
        self.assertIn(f'Logger(subsystem: "com.henning.looseends", {CATEGORY})', self.source)

    def test_fields_present(self):
        for needle in ("callStackSymbols", "NSApp.currentEvent", "frontmostApplication", "activationPolicy"):
            self.assertIn(needle, self.source, needle)

    def test_events_cover_hiding(self):
        """Run 44994038524: the SwiftUI panel is ordered out, never closed; resign and hide leave a line too."""
        for name in ("didBecomeKeyNotification", "willCloseNotification",
                     "didResignKeyNotification", "didChangeOcclusionStateNotification"):
            self.assertIn(f"NSWindow.{name}", self.source, name)
        for event in ('"key"', '"close"', '"resign"', '"hide"'):
            self.assertIn(event, self.source, event)

    def test_hiding_does_not_touch_dock_policy(self):
        """AC-4: resign and hide only log, the Dock policy runs as often as before."""
        self.assertNotIn("applyDockPolicy", function_body(self.source, "observePanelHiding"))

    def test_notice_level(self):
        self.assertRegex(self.source, r"panelLogger\.notice\(")

    def test_no_titles_print_or_try_optional(self):
        lines = [l for l in self.source.splitlines() if "panelLogger" in l]
        self.assertTrue(lines, "keine panelLogger-Zeilen")
        for line in lines:
            self.assertNotIn(".title", line)
        self.assertNotRegex(self.source, r"\bprint\(")
        self.assertNotIn("try?", self.source)


class CiCollectsPanelLog(unittest.TestCase):
    """AC-5: ein Schritt nach der Galerie sammelt die Zeilen und lädt sie hoch, ohne den Job rot zu machen."""

    def test_collect_step(self):
        step = panel_log_step()
        self.assertEqual(step.get("if"), "always()")
        self.assertTrue(step.get("continue-on-error"))
        self.assertIn("log show", step["run"])
        self.assertIn('subsystem == "com.henning.looseends"', step["run"])

    def test_collect_after_gallery(self):
        steps = mac_gallery_steps()
        gallery = next(i for i, s in enumerate(steps) if "MacGalleryTests" in (s.get("run") or ""))
        self.assertGreater(steps.index(panel_log_step()), gallery)

    def test_upload(self):
        upload = panel_log_upload()
        self.assertEqual(upload.get("if"), "always()")
        self.assertTrue(upload.get("continue-on-error"))
        self.assertEqual(upload["with"].get("if-no-files-found"), "warn")


if __name__ == "__main__":
    unittest.main()
