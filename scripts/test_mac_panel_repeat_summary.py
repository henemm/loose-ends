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
import shutil
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


def write_how_export(folder: Path, clicks: list[tuple[str, float, bool, str]]) -> None:
    """Wie `write_export`, aber der Anhang trägt die Zeile `how:` wie `assertSymbolOpensPanelWithOneClick`."""
    folder.mkdir(parents=True, exist_ok=True)
    tests = {}
    for index, (label, at, opened, how) in enumerate(clicks):
        file_name = f"{index:04d}-click.txt"
        lines = click_text(at, opened).splitlines()
        (folder / file_name).write_text("\n".join([lines[0], f"how: {how}", *lines[1:]]) + "\n")
        tests.setdefault(f"MacGalleryTests/test-{label}()", []).append({
            "exportedFileName": file_name,
            "suggestedHumanReadableName": f"mac-gallery-{label}-click_0_{index:04d}.txt",
        })
    manifest = [{"testIdentifier": k, "attachments": v} for k, v in tests.items()]
    (folder / "manifest.json").write_text(json.dumps(manifest))


class ExpectedAndHowTests(unittest.TestCase):
    """F001: Nenner gegen die Iterationszahl; F004: Klickweg je Arm."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)

    def run_script(self, *extra):
        log = self.base / "panel.log"
        log.write_text("")
        out = self.base / "summary.md"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--raw", str(self.base / "raw"), "--log", str(log), "--out", str(out),
             *extra], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out.read_text()

    def test_expected_flags_short_active_arm(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)] * 3 + [("reopen-open-app", 2.0, True)] * 2
                     + [("reopen-return-control", 3.0, True)] * 3)
        text = self.run_script("--expected", "3")
        self.assertIn("open-app: erwartet 3, gezählt 2", text)
        self.assertNotIn("return: erwartet", text)
        self.assertNotIn("control: erwartet", text)

    def test_expected_ignores_inactive_control_arm(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)] * 2 + [("reopen-open-app", 2.0, True)] * 2)
        text = self.run_script("--expected", "2")
        self.assertNotIn("erwartet", text)

    def test_expected_flags_named_arm_without_clicks(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)] * 2 + [("reopen-open-app", 2.0, True)] * 2)
        text = self.run_script("--expected", "2", "--arms", "return,open-app,control")
        self.assertIn("control: erwartet 2, gezählt 0", text)

    def test_mandatory_arms_flagged_even_without_clicks(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)] * 2)
        text = self.run_script("--expected", "2")
        self.assertIn("open-app: erwartet 2, gezählt 0", text)
        self.assertNotIn("control: erwartet", text)

    def test_without_expected_no_check_line(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)])
        self.assertNotIn("erwartet", self.run_script())

    def test_how_counted_per_arm(self):
        write_how_export(self.base / "raw", [
            ("reopen-return-control", 1.0, True, "control: CGEvent at 1200,12"),
            ("reopen-return-control", 2.0, True, "control: CGEvent at 1200,12"),
            ("reopen-return-control", 3.0, False, "control: XCUICoordinate fallback"),
            ("reopen-return", 4.0, True, "user: statusItem.click()"),
        ])
        how = self.summary.count_how([self.base / "raw"])
        self.assertEqual(how["control"], {"cgevent": 2, "xcuicoordinate": 1})
        self.assertEqual(how["return"], {"statusitem": 1})
        self.assertEqual(how["open-app"], {})
        text = self.run_script()
        self.assertIn("control: cgevent 2, xcuicoordinate 1", text)
        self.assertIn("return: statusitem 1", text)

    def test_how_v3_categories(self):
        """#978 S3 v3 AC-5: die drei neuen Texte, spezifische vor `statusItem.click()`."""
        cases = {
            "user: frontmost menu bar com.apple.finder": "menubar-root",
            "user: statusItem.click() fallback (frontmost com.henning.looseends)": "fallback-looseends",
            "user: statusItem.click() fallback (frontmost com.apple.finder, no menu bar frame)": "fallback-noframe",
            "user: statusItem.click()": "statusitem",
        }
        for how, name in cases.items():
            self.assertEqual(self.summary.how_of(f"click: 1.0 (seconds since 1970)\nhow: {how}\n"), name, how)

    def test_how_v3_counted_and_rates_unchanged(self):
        write_how_export(self.base / "raw", [
            ("reopen-open-app", 1.0, True, "user: frontmost menu bar com.apple.finder"),
            ("reopen-open-app", 2.0, True, "user: frontmost menu bar com.apple.finder"),
            ("reopen-open-app", 3.0, False, "user: statusItem.click() fallback (frontmost com.apple.finder, no menu bar frame)"),
            ("reopen-return", 4.0, True, "user: statusItem.click() fallback (frontmost com.henning.looseends)"),
        ])
        how = self.summary.count_how([self.base / "raw"])
        self.assertEqual(how["open-app"], {"menubar-root": 2, "fallback-noframe": 1})
        self.assertEqual(how["return"], {"fallback-looseends": 1})
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["open-app"]["n"], 3)
        self.assertEqual(counts["open-app"]["fails"], 1)
        self.assertAlmostEqual(counts["open-app"]["rate"], 1 / 3)
        self.assertEqual(counts["return"], {"n": 1, "fails": 0, "rate": 0.0})
        text = self.run_script()
        self.assertIn("open-app: menubar-root 2, fallback-noframe 1", text)
        self.assertIn("return: fallback-looseends 1", text)

    def test_attachment_without_how_counts_as_unknown(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True)])
        self.assertEqual(self.summary.count_how([self.base / "raw"])["return"], {"unbekannt": 1})


class WorkflowExpectedTests(unittest.TestCase):
    """F001: der Workflow übergibt die Iterationszahl und die aktiven Arme."""

    def test_workflow_passes_expected_and_arms(self):
        text = WORKFLOW.read_text()
        for needle in ('--expected "$ITERATIONS"', "--arms"):
            self.assertTrue(needle in text, f"fehlt: {needle}")


class CallersTests(unittest.TestCase):
    """F003: nur die führenden Rahmen des Beobachters fallen weg, tiefere bleiben."""

    AFTER_OBSERVER = r"nonisolated static func afterObserver\(_ frames: \[String\]\) -> ArraySlice<String> \{.*?\n    \}\n"

    def after_observer_source(self):
        body = re.search(self.AFTER_OBSERVER, CAPTURE.read_text(), re.S)
        self.assertIsNotNone(body, "afterObserver fehlt in MenuBarCapture.swift")
        return body.group(0)

    def test_callers_drops_only_leading_frames(self):
        text = CAPTURE.read_text()
        callers = re.search(r"static func callers\(\).*?\n    \}\n", text, re.S)
        self.assertIsNotNone(callers)
        self.assertIn("afterObserver(", callers.group(0))
        body = self.after_observer_source()
        # Ein zusammenhängender Block ab dem ersten Beobachterrahmen, kein Filter: tiefere Rahmen bleiben.
        self.assertIn("frames.firstIndex(where: isObserver)", body)
        self.assertIn("break", body)
        self.assertIn("frames[(last + 1)...]", body)
        self.assertNotIn(".filter", body)

    def test_after_observer_behaviour(self):
        """F101: der echte Rumpf von `afterObserver`, mit swiftc gebaut und an festen Stapeln ausgeführt."""
        swiftc = shutil.which("swiftc")
        if swiftc is None:
            self.skipTest("swiftc fehlt")
        body = self.after_observer_source()
        cases = {
            "ci": [
                "$sxs5Error_pIgrzo_xsAA_pIegrzo_s8SendableRzlTR + 24",
                "$sScM14assumeIsolated_x + 424",
                "$s9LooseEnds14MacAppDelegateC14observeWindows_x",
                "$s10Foundation12NotificationVIeghn_So14NSNotificationCIeyBhy_TR + 184",
                "-[NSWindow becomeKeyWindow] + 856",
            ],
            "none": ["a", "b", "c"],
            "deeper": ["t", "MacAppDelegate a", "MenuBarPanelLog b", "y", "MacAppDelegate z"],
            "empty": [],
            "real": [
                "$s9LooseEnds15MenuBarPanelLogO7callersSSyFZ + 40",
                "$s9LooseEnds15MenuBarPanelLogO6record_4kind5isKeyySS_SSSbSgtFZ + 120",
                "$sxs5Error_pIgrzo_xsAA_pIegrzo_s8SendableRzlTR + 24",
                "$sxs5Error_pIgrzo_xsAA_pIegrzo_s8SendableRzlTRTA + 40",
                "$sScM14assumeIsolated_4file4linexxyKScMYcXE_s12StaticStringVSutKs8SendableRzlFZxxyKScMYccKXEfU_ + 28",
                "$sScM14assumeIsolated_4file4linexxyKScMYcXE_s12StaticStringVSutKs8SendableRzlFZ + 424",
                "$s9LooseEnds14MacAppDelegateC14observeWindows33_8D4C992FC3BD3E72A3716DA16207BEB7LLyyFy10Foundation12NotificationVYbcfU_ + 840",
                "$s10Foundation12NotificationVIeghn_So14NSNotificationCIeyBhy_TR + 184",
                "__CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ + 128",
                "-[NSWindow becomeKeyWindow] + 856",
                "$s9LooseEnds14MacAppDelegateC8showMainyyF + 12",
            ],
            "glue": ["MenuBarPanelLog a", "$sabcTR + 4", "MacAppDelegate b", "x"],
        }
        main = "\n".join(
            f"print(\"{name}\\t\" + Array(P.afterObserver({json.dumps(frames)} as [String])).joined(separator: \"\\u{{1F}}\"))"
            for name, frames in cases.items()
        )
        source = "import Foundation\n\nenum P {\n" + body + "}\n\n" + main + "\n"
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "main.swift"
            exe = Path(tmp) / "probe"
            src.write_text(source)
            build = subprocess.run([swiftc, "-swift-version", "6", str(src), "-o", str(exe)],
                                   capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(exe)], capture_output=True, text=True, check=True)
        out = {}
        for line in run.stdout.splitlines():
            name, _, rest = line.partition("\t")
            out[name] = rest.split("\x1f") if rest else []
        self.assertEqual(out["ci"], cases["ci"][3:])
        self.assertTrue(out["ci"][0].startswith("$s10Foundation12Notification"))
        self.assertEqual(len(out["ci"]), 2)
        self.assertEqual(out["none"], cases["none"])
        self.assertEqual(out["deeper"], ["y", "MacAppDelegate z"])
        self.assertEqual(out["empty"], [])
        # F102: echte Form aus dem CI-Lauf 45249742660 – eigene Rahmen, Thunks und assumeIsolated vor dem Beobachter.
        self.assertEqual(out["real"], cases["real"][7:])
        self.assertTrue(out["real"][0].startswith("$s10Foundation12Notification"))
        self.assertEqual(out["real"][-1], "$s9LooseEnds14MacAppDelegateC8showMainyyF + 12")
        # F103: Klebstoff zwischen zwei Beobachterrahmen fällt mit weg.
        self.assertEqual(out["glue"], ["x"])


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

    def test_user_arms_click_through_frontmost_root_with_statusitem_fallback(self):
        """#978 S3 v2: Nutzerarme klicken über frontmostRootClick, dessen Rückfall ist statusItem.click().
        Kommentare zählen nicht."""
        def body(name):
            match = re.search(rf"func {name}\(.*?\n    \}}\n", self.text, re.S)
            self.assertIsNotNone(match, f"fehlt: func {name}")
            return re.sub(r"//.*$", "", match.group(0), flags=re.M)
        self.assertIn("frontmostRootClick(", body("assertSymbolOpensPanelWithOneClick"))
        self.assertIn("statusItem.click()", body("frontmostRootClick"))
        self.assertIn(".menuBars.element(boundBy: 0)", body("frontmostRootClick"), "#978 S3 v3: Wurzel = Menüleiste")


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
