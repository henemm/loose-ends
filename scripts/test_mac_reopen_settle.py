"""Tests für #978: Wiederöffnungstests des Menüleisten-Panels, Gegenprobe am Quelltext.

v5 (nach der Halteprobe v4, Lauf 45602877961: 1,0 s Halten schloss 20/20, 0,1 s 0/20): Überall, wo der Test das
Menüleistensymbol klickt (`openPanel`, beide Nutzerarme), klickt er wie ein Mensch kurz, 0,1 s, über einen Helfer
`shortClick` mit `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate. Keine Wiederholung, jeder
Fehlschlag hart rot. Die Klickwege aus v1 (`waitForFrontmostSettled`) und v3 (`frontmostRootClick`) und die
Rückfall-Regel entfallen. Kontrollarm und Halteprobe bleiben hinter ihren Umgebungsvariablen.

v6 (nach Befund v5, Lauf 45642831767: Open-App-Arm 1/40 zu, Haltedauer 0,616 s): Der Klick bleibt `shortClick`. Hält
der erste Klick das Panel nicht, liest der Test die Haltedauer aus dem Panel-Protokoll der App (`MacPanelHold.read`,
`OSLogStore.local()`); ab 0,4 s folgt genau ein zweiter kurzer Klick mit dem Vermerk `retry: hold X s`, sonst (unter
0,4 s, „kurz“, „unbekannt“) bleibt der Test hart rot. Es gibt genau einen Retry-Pfad, gemeinsam für `openPanel` und
`assertSymbolOpensPanelWithOneClick`.

v7 (nach Befund v6, Lauf 45658361541: `OSLogStore.local()` im Läufer „Connection to logd failed“, 40 von 40): Klick,
Retry-Pfad und Schwelle bleiben, nur die Quelle der Haltedauer wechselt. Die App misst unter `--ui-testing` die Strecke
`key` → erstes Maus-hoch selbst und setzt sie als Accessibility-Wert des Statusobjekts (`round=<n> pending|<s>|short`);
der Test liest die Runde vor dem Klick (`MacPanelHold.round(of:)`) und danach `MacPanelHold.read(_:after:)`.

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
APP_CAPTURE = ROOT / "LooseEnds" / "Mac" / "MenuBarCapture.swift"
GALLERY_TESTS = ROOT / "LooseEndsUITests" / "MacGalleryTests.swift"
PANEL_HOLD = ROOT / "LooseEndsUITests" / "MacPanelHold.swift"
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


def functions(text: str) -> dict:
    """Name → Rumpf jeder Funktion der Klasse (Einrückung 4, Ende an der ersten `    }`-Zeile)."""
    return {m.group(1): m.group(0) for m in re.finditer(r"^    (?:[a-z@]\w* )*func (\w+)\(.*?\n    \}\n", text, re.S | re.M)}


class RetryPathSourceTests(unittest.TestCase):
    """Spec v6 Test 4 und AC-2: genau ein Retry-Pfad, Schwelle 0,4 s, nur nach gelesener Haltedauer, höchstens einmal."""

    def setUp(self):
        self.raw = GALLERY_TESTS.read_text()
        self.text = strip_comments(self.raw)
        bodies = {name: strip_comments(body) for name, body in functions(self.raw).items()}
        retry = [name for name, body in bodies.items() if "retry: hold" in body]
        self.assertEqual(len(retry), 1, f"genau eine Funktion mit dem Vermerk `retry: hold`, gefunden: {retry}")
        self.name = retry[0]
        self.retry = bodies[self.name]
        self.bodies = bodies

    def test_vermerk_and_threshold_exactly_once(self):
        self.assertEqual(self.text.count("retry: hold"), 1, "genau ein Vermerk `retry: hold`")
        self.assertEqual(len(re.findall(r"(?<![\d.])0\.4(?![\d])", self.text)), 1, "Schwelle 0.4 genau einmal")

    def test_both_click_ways_share_the_one_retry_path(self):
        for caller in ("openPanel", "assertSymbolOpensPanelWithOneClick"):
            self.assertEqual(len(re.findall(rf"\b{self.name}\(", self.bodies[caller])), 1,
                             f"{caller} ruft den Retry-Pfad genau einmal")

    def test_every_click_way_reads_the_round_before_its_click(self):
        """Spec v7 AC-4: jeder Klickweg liest die Runde des Statusobjekts vor dem Klick, nicht mehr eine Uhrzeit."""
        for name, click in (("openPanel", "shortClick("), ("assertSymbolOpensPanelWithOneClick", "shortClick("),
                            ("holdClick", ".click(forDuration: seconds")):
            body = self.bodies[name]
            self.assertEqual(body.count("MacPanelHold.round(of: statusItem)"), 1, f"{name} liest die Runde genau einmal")
            self.assertLess(body.find("MacPanelHold.round(of: statusItem)"), body.find(click),
                            f"{name}: Runde vor dem Klick lesen")
        self.assertNotIn("since: clickedAt", self.text, "keine Zeitquelle mehr für die Haltedauer")
        self.assertRegex(self.retry, r"MacPanelHold\.read\(statusItem, after: \w+\)", "Lesen nach der Runde vor dem Klick")
        self.assertRegex(self.bodies["holdClick"], r"MacPanelHold\.read\(statusItem, after: \w+\)")

    def test_retry_reads_hold_first_then_one_short_click(self):
        read = self.retry.find("MacPanelHold.read(")
        click = self.retry.find("shortClick(")
        self.assertEqual(self.retry.count("MacPanelHold.read("), 1, "Haltedauer genau einmal lesen")
        self.assertEqual(self.retry.count("shortClick("), 1, "höchstens eine Wiederholung")
        self.assertTrue(0 <= read < click, "erst die Haltedauer lesen, dann klicken")
        self.assertFalse(re.search(r"\b(for|while|repeat)\b", self.retry), "keine Schleife")

    def test_retry_only_on_read_seconds_at_or_above_threshold(self):
        """Kein Retry ohne gelesene Haltedauer: „kurz“ und „unbekannt“ führen nie zum zweiten Klick."""
        self.assertRegex(self.retry, r"case \.seconds\(let (\w+)\)[^\n{]*\b\1 >= ",
                         "zweiter Klick nur bei `.seconds(x)` mit x >= Schwelle")
        guard = re.search(r"case \.seconds\(let (\w+)\)[^\n{]*\b\1 >= [^\n{]*", self.retry)
        self.assertLess(guard.start(), self.retry.find("shortClick("), "die Bedingung steht vor dem Klick")

    def test_no_retry_elsewhere(self):
        """Außer dem Retry-Pfad liest nur die Halteprobe die Haltedauer (für ihren Anhang, ohne zweiten Klick)."""
        for name, body in self.bodies.items():
            if name not in (self.name, "holdClick"):
                self.assertNotIn("MacPanelHold.read(", body, f"{name} liest die Haltedauer nicht")
        self.assertNotIn("shortClick(", self.bodies["holdClick"].split("MacPanelHold.read(", 1)[-1],
                         "die Halteprobe klickt nach dem Lesen nicht nach")

    def test_failure_names_hold_or_reason(self):
        """Hart rot mit Haltedauer oder Grund in der Meldung; der Klickanhang trägt eine Zeile `hold:`."""
        helper = self.bodies["assertSymbolOpensPanelWithOneClick"]
        literal = re.search(r'XCTAttachment\(string: """\n(.*?)"""', helper, re.S)
        self.assertIsNotNone(literal, "Anhangtext fehlt")
        self.assertTrue(any(line.strip().startswith("hold:") for line in literal.group(1).splitlines()),
                        "Anhang ohne Zeile `hold:`")
        assertion = re.search(r"XCTAssertTrue\(opened,.*?\)\n", helper, re.S)
        self.assertIsNotNone(assertion, "XCTAssertTrue(opened, …) fehlt")
        self.assertIn("hold", assertion.group(0), "die Meldung nennt Haltedauer oder Grund")

    def test_hold_probe_writes_read_hold(self):
        body = self.bodies["holdClick"]
        self.assertEqual(body.count("MacPanelHold.read("), 1, "die Probe liest die Haltedauer je Klick")
        self.assertIn('"read hold: ', body, "Anhangzeile `read hold:` fehlt")


class MacPanelHoldSourceTests(unittest.TestCase):
    """Spec v7 Test 1 und AC-2: der Helfer liest den Accessibility-Wert des Statusobjekts, nicht das Protokoll."""

    def setUp(self):
        self.assertTrue(PANEL_HOLD.is_file(), f"{PANEL_HOLD.relative_to(ROOT)} fehlt")
        self.raw = PANEL_HOLD.read_text()
        self.text = strip_comments(self.raw)

    def test_macos_only_without_oslog(self):
        self.assertTrue(self.text.lstrip().startswith("#if os(macOS)"), "nur macOS")
        self.assertNotIn("import OSLog", self.text)
        self.assertNotIn("OSLogStore", self.text)
        self.assertIn("import XCTest", self.text)

    def test_reads_value_of_status_item(self):
        self.assertRegex(self.text, r"static func round\(of statusItem: XCUIElement\) -> Int")
        self.assertRegex(self.text, r"static func read\(_ statusItem: XCUIElement, after round: Int\) -> Reading")
        self.assertIn("statusItem.value", self.text)

    def test_round_format_pending_short(self):
        self.assertIn('"round="', self.text)
        self.assertIn('"pending"', self.text)
        self.assertIn('"short"', self.text)

    def test_waits_at_most_4_s(self):
        self.assertRegex(self.text, r"static let wait: TimeInterval = 4\b", "höchstens 4 s warten")

    def test_results_seconds_short_unknown_with_reason(self):
        self.assertRegex(self.text, r"case seconds\(TimeInterval\)")
        self.assertRegex(self.text, r"case short\b")
        self.assertRegex(self.text, r"case unknown\(String\)")
        self.assertIn("var text: String", self.text)
        self.assertGreaterEqual(self.text.count(".unknown("), 2, "Gründe: Wert fehlt/unlesbar, keine neue Runde")

    def test_no_try_optional_and_no_print(self):
        self.assertNotIn("try?", self.text)
        self.assertNotRegex(self.text, r"\bprint\(")


class AppHoldValueSourceTests(unittest.TestCase):
    """Spec v7 Test 2 und AC-3: die App setzt den Wert am Statusobjekt, nur unter `--ui-testing`."""

    def setUp(self):
        self.raw = APP_CAPTURE.read_text()
        self.text = strip_comments(self.raw)
        match = re.search(r"enum MenuBarPanelLog \{.*?\n\}\n", self.text, re.S)
        self.assertIsNotNone(match, "enum MenuBarPanelLog fehlt")
        self.log = match.group(0)

    def test_set_through_status_bar_button(self):
        self.assertIn("setAccessibilityValue(", self.log)
        self.assertIn('"NSStatusBarWindow"', self.log)
        self.assertIn("NSStatusBarButton", self.log)
        self.assertIn("NSApp.windows", self.log)

    def test_only_under_ui_testing(self):
        setter = re.search(r"func showHold\(.*?\n    \}\n", self.log, re.S)
        self.assertIsNotNone(setter, "func showHold fehlt (der eine Setzer des Werts)")
        self.assertRegex(setter.group(0), r"guard ModelContainerFactory\.isUITesting else \{ return \}")
        self.assertEqual(self.log.count("setAccessibilityValue("), 1, "nur showHold setzt den Wert")

    def test_pending_at_key_with_uptime(self):
        start = re.search(r"func startMonitors\(\).*?\n    \}\n", self.log, re.S).group(0)
        self.assertIn("ProcessInfo.processInfo.systemUptime", start)
        self.assertRegex(start, r'showHold\(round: round, "pending"\)')

    def test_first_mouse_up_within_round_sets_seconds(self):
        self.assertRegex(self.log, r"\.leftMouseUp")
        self.assertRegex(self.log, r'String\(format: "%\.3f"')
        self.assertGreaterEqual(len(re.findall(r"mouseUp\(", self.log)), 3, "lokal und global melden das Maus-hoch")

    def test_round_end_without_mouse_up_is_short(self):
        self.assertRegex(self.log, r'showHold\(round: round, "short"\)')
        self.assertIn('"round=\\(round) \\(state)"', self.log)

    def test_log_lines_unchanged(self):
        for line in ('panelLogger.notice("monitor end")',
                     'panelLogger.notice("monitor \\(scope, privacy: .public) type=\\(type, privacy: .public) window=\\(window, privacy: .public) time=\\(time, privacy: .public)")'):
            self.assertIn(line, self.raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
