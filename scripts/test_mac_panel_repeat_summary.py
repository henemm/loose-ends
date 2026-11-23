"""Tests für #978 Schnitt 2: Auswertung des Wiederholungslaufs und die Bausteine dazu.

Aufruf: python3 scripts/test_mac_panel_repeat_summary.py
Die CI fährt die Datei mit `unittest discover -s scripts -p 'test_*.py'`.

Geprüft wird mit festen Eingaben:
- `scripts/mac_panel_repeat_summary.py` zählt je Arm (Return, Open-App, Kontrollarm) Nenner, Zähler und Rate aus den
  exportierten `mac-gallery-<label>-click`-Anhängen und baut je Fall die Zeitachse aus dem Panel-Protokoll (AC-5, AC-7).
- Der Wiederholungsworkflow, der Kontrollarm und die Protokollerweiterung stehen so im Repo, wie die Spec sie verlangt
  (AC-1 bis AC-4, AC-6), als Gegenprobe am Quelltext; den Lauf selbst belegen die CI-Artefakte.
"""
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "mac_panel_repeat_summary.py"
WORKFLOW = ROOT / ".github" / "workflows" / "mac-panel-repeat.yml"
GALLERY_TESTS = ROOT / "LooseEndsUITests" / "MacGalleryTests.swift"
CAPTURE = ROOT / "LooseEnds" / "Mac" / "MenuBarCapture.swift"


def load_summary():
    """Lädt das Auswertungsskript als Modul; fehlt es, schlägt der Test mit klarer Meldung fehl."""
    if not SCRIPT.is_file():
        raise AssertionError(f"{SCRIPT.relative_to(ROOT)} fehlt")
    spec = importlib.util.spec_from_file_location("mac_panel_repeat_summary", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def click_text(clicked_at: float, opened: bool) -> str:
    """So schreibt `assertSymbolOpensPanelWithOneClick` den Anhang (MacGalleryTests.swift)."""
    return (
        f"click: {clicked_at:.3f} (seconds since 1970)\n"
        f"after: {0.4 if opened else 10.02:.2f} s, panel {'open' if opened else 'not open'}\n"
        "Attributes: Application, pid: 4711, label: 'Loose Ends'\n"
    )


def write_export(folder: Path, clicks: list[tuple[str, float, bool]]) -> None:
    """Baut einen Ordner wie `xcresulttool export attachments`: Dateien plus manifest.json."""
    folder.mkdir(parents=True, exist_ok=True)
    tests = {}
    for index, (label, at, opened) in enumerate(clicks):
        file_name = f"{index:04d}-click.txt"
        (folder / file_name).write_text(click_text(at, opened))
        test_id = f"MacGalleryTests/test-{label}()"
        tests.setdefault(test_id, []).append({
            "exportedFileName": file_name,
            "suggestedHumanReadableName": f"mac-gallery-{label}-click_0_{index:04d}.txt",
        })
    # Fremde Anhänge zählen nie mit.
    (folder / "foo.png").write_bytes(b"png")
    tests.setdefault("MacGalleryTests/testStart()", []).append(
        {"exportedFileName": "foo.png", "suggestedHumanReadableName": "mac-gallery-start-light_0_1.png"})
    manifest = [{"testIdentifier": k, "attachments": v} for k, v in tests.items()]
    (folder / "manifest.json").write_text(json.dumps(manifest))


# Ein Fall: Klick um 1763900000.000 (2025-11-23 12:13:20 UTC), key 0,2 s danach, resign mit Ereignis 21 nach 0,9 s.
CLICK_FAIL = 1763900000.000
PANEL_LOG = """\
Timestamp               Ty Process[PID:TID]
2025-11-23 12:13:20.200 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=type=1,window=88,target=10920,source=0,time=1 active=true keyWindow=true front=com.henning.looseends policy=accessory stack=a | b
2025-11-23 12:13:20.650 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] monitor local type=2 window=88 time=2
2025-11-23 12:13:21.100 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel resign window=MenuBarExtraWindow<AnyView> event=21 cg=type=21,window=0,target=10920,source=612,time=3 active=false keyWindow=false front=com.apple.dt.xctest.tool policy=accessory stack=c | d
2025-11-23 12:13:21.150 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel hide window=MenuBarExtraWindow<AnyView> event=21 cg=nil front=com.apple.dt.xctest.tool policy=accessory stack=e
2025-11-23 12:20:00.000 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=nil active=true keyWindow=true front=x policy=accessory stack=f
"""


class SummaryTests(unittest.TestCase):
    """AC-5, AC-7: Nenner, Zähler, Rate je Arm und die Zeitachse eines Falls."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)

    def test_arm_of_maps_labels(self):
        self.assertEqual(self.summary.arm_of("mac-gallery-reopen-return-click_0_1.txt"), "return")
        self.assertEqual(self.summary.arm_of("mac-gallery-reopen-open-app-click_0_1.txt"), "open-app")
        self.assertEqual(self.summary.arm_of("mac-gallery-reopen-return-control-click_0_1.txt"), "control")
        self.assertIsNone(self.summary.arm_of("mac-gallery-start-light_0_1.png"))
        self.assertIsNone(self.summary.arm_of("mac-gallery-reopen-return-window-size_0_1.txt"))

    def test_parse_click(self):
        self.assertEqual(self.summary.parse_click(click_text(1763900000.5, True)), (1763900000.5, True))
        self.assertEqual(self.summary.parse_click(click_text(1763900001.25, False)), (1763900001.25, False))

    def test_counts_every_iteration_per_arm(self):
        write_export(self.base / "raw", [
            ("reopen-return", 1.0, True), ("reopen-return", 2.0, False), ("reopen-return", 3.0, True),
            ("reopen-return", 4.0, True), ("reopen-open-app", 5.0, True), ("reopen-open-app", 6.0, True),
            ("reopen-return-control", 7.0, True),
        ])
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["return"], {"n": 4, "fails": 1, "rate": 0.25})
        self.assertEqual(counts["open-app"], {"n": 2, "fails": 0, "rate": 0.0})
        self.assertEqual(counts["control"], {"n": 1, "fails": 0, "rate": 0.0})

    def test_arm_without_attachments_is_zero_not_missing(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)])
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["control"], {"n": 0, "fails": 0, "rate": None})

    def test_several_export_folders_add_up(self):
        write_export(self.base / "a", [("reopen-return", 1.0, False)])
        write_export(self.base / "b", [("reopen-return", 2.0, True)])
        counts = self.summary.count_arms([self.base / "a", self.base / "b"])
        self.assertEqual(counts["return"], {"n": 2, "fails": 1, "rate": 0.5})

    def test_parse_panel_log_reads_event_and_source(self):
        events = self.summary.parse_panel_log(PANEL_LOG)
        self.assertEqual(len(events), 5)
        resign = events[2]
        self.assertEqual(resign["kind"], "resign")
        self.assertEqual(resign["event"], 21)
        self.assertEqual(resign["source"], 612)
        self.assertAlmostEqual(resign["time"], CLICK_FAIL + 1.1, places=3)
        self.assertEqual(events[1]["kind"], "monitor local")
        self.assertIsNone(events[3]["source"])

    def test_timeline_of_a_failure(self):
        events = self.summary.parse_panel_log(PANEL_LOG)
        line = self.summary.timeline(CLICK_FAIL, events)
        offsets = [round(entry["offset"], 2) for entry in line]
        kinds = [entry["kind"] for entry in line]
        self.assertEqual(kinds, ["click", "key", "monitor local", "resign", "hide"])
        self.assertEqual(offsets, [0.0, 0.2, 0.65, 1.1, 1.15])
        self.assertEqual(line[3]["event"], 21)
        self.assertEqual(line[3]["source"], 612)

    def test_report_names_every_arm_and_only_numbers(self):
        write_export(self.base / "raw", [
            ("reopen-return", CLICK_FAIL, False), ("reopen-return", 1.0, True), ("reopen-open-app", 2.0, True),
            ("reopen-return-control", 3.0, True),
        ])
        log = self.base / "panel.log"
        log.write_text(PANEL_LOG)
        out = self.base / "summary.md"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--raw", str(self.base / "raw"), "--log", str(log), "--out", str(out)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        text = out.read_text()
        for arm, row in (("return", "| return | 2 | 1 | 50.0 % |"), ("open-app", "| open-app | 1 | 0 | 0.0 % |"),
                         ("control", "| control | 1 | 0 | 0.0 % |")):
            self.assertIn(row, text, arm)
        self.assertIn("event=21", text)
        self.assertIn("source=612", text)
        # Nur Zeiten, Typnummern und PIDs: kein Fenstertitel, keine Bundle-ID, kein Stapel.
        self.assertNotIn("MenuBarExtraWindow", text)
        self.assertNotIn("com.apple", text)
        self.assertNotIn("stack=", text)


class SourceCheck(unittest.TestCase):
    """Prüft einen Quelltext; Meldungen nennen nur das Gesuchte, nie den ganzen Text."""

    text = ""

    def has(self, needle):
        self.assertTrue(needle in self.text, f"fehlt: {needle}")

    def lacks(self, needle):
        self.assertFalse(needle in self.text, f"darf nicht stehen: {needle}")

    def matches(self, pattern):
        self.assertTrue(re.search(pattern, self.text), f"kein Treffer: {pattern}")

    def never_matches(self, pattern):
        self.assertFalse(re.search(pattern, self.text), f"darf nicht passen: {pattern}")


class WorkflowTests(SourceCheck):
    """AC-4: der Wiederholungsworkflow."""

    def setUp(self):
        self.assertTrue(WORKFLOW.is_file(), f"{WORKFLOW.relative_to(ROOT)} fehlt")
        self.text = WORKFLOW.read_text()

    def test_dispatch_with_inputs(self):
        self.has("workflow_dispatch:")
        for name in ("iterationen:", "kontrollarm:", "sandbox:"):
            self.has(name)

    def test_pull_request_only_on_this_file(self):
        self.matches(r"pull_request:\s*\n\s*paths:\s*\n\s*-\s*['\"]?\.github/workflows/mac-panel-repeat\.yml")

    def test_runs_only_reopen_tests_with_iterations(self):
        self.has("-test-iterations")
        self.lacks("-run-tests-until-failure")
        self.has("testMenuBarReopensAfterReturnWithOneClick")
        self.has("testMenuBarReopensAfterOpenAppWithOneClick")
        self.has("LE_PANEL_CONTROL_ARM")
        self.has("select-xcode-27")
        self.has("mac_ci_entitlements.py")

    def test_log_from_job_start_and_uploads(self):
        self.has("--start")
        for name in ("MacPanelRepeatLog", "MacPanelRepeatResults", "MacPanelRepeatSummary"):
            self.has(name)
        self.has("mac_panel_repeat_summary.py")
        self.has("GITHUB_STEP_SUMMARY")
        self.has("timeout-minutes: 120")


class ControlArmTests(SourceCheck):
    """AC-6: Kontrollarm hinter der Umgebungsvariable, Pflichttests klicken wie ein Nutzer."""

    def setUp(self):
        self.text = GALLERY_TESTS.read_text()

    def test_control_arm_guarded_by_env(self):
        self.has("LE_PANEL_CONTROL_ARM")
        self.matches(r"XCTSkip\(")
        self.has('"reopen-return-control"')

    def test_user_arms_keep_statusitem_click(self):
        helper = re.search(r"func assertSymbolOpensPanelWithOneClick\(.*?\n    \}\n", self.text, re.S)
        self.assertIsNotNone(helper)
        self.assertIn("statusItem.click()", helper.group(0))


class PanelLogTests(SourceCheck):
    """AC-1 bis AC-3, Gegenprobe am Quelltext; die Zeilen selbst belegt das Artefakt MacGalleryPanelLog."""

    def setUp(self):
        self.text = CAPTURE.read_text()

    def test_stack_up_to_40_frames(self):
        self.has("prefix(40)")
        self.lacks("prefix(12)")

    def test_cg_event_fields_without_subtype_or_data1(self):
        self.has("cgEvent")
        self.has("eventSourceUnixProcessID")
        self.never_matches(r"\.subtype\b")
        self.never_matches(r"\.data1\b")

    def test_activation_and_space_lines(self):
        for name in ("didBecomeActiveNotification", "didResignActiveNotification", "didHideNotification",
                     "didActivateApplicationNotification", "activeSpaceDidChangeNotification"):
            self.has(name)
        self.has("isKeyWindow")
        self.has("NSApp.isActive")

    def test_monitors_return_event_unchanged(self):
        self.has("addLocalMonitorForEvents")
        self.has("addGlobalMonitorForEvents")
        self.has("removeMonitor")

    def test_no_print_no_try_optional(self):
        self.never_matches(r"\bprint\(")
        self.lacks("try?")


if __name__ == "__main__":
    unittest.main(verbosity=2)
