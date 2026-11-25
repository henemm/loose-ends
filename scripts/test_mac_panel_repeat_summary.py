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

    def test_how_short_click_category(self):
        """#978 S5 Test 3: `user: short click 0.1 s` ist eine eigene Kategorie; die v3-Klickwege gibt es nicht mehr."""
        text = "click: 1.0 (seconds since 1970)\nhow: {}\n"
        self.assertEqual(self.summary.how_of(text.format("user: short click 0.1 s")), "short-click")
        for gone in ("user: frontmost menu bar com.apple.finder",
                     "user: statusItem.click() fallback (frontmost com.henning.looseends)",
                     "user: statusItem.click() fallback (frontmost com.apple.finder, no menu bar frame)"):
            self.assertEqual(self.summary.how_of(text.format(gone)), "unbekannt", gone)
        names = [name for _, name in self.summary._HOW]
        for gone in ("menubar-root", "fallback-looseends", "fallback-noframe"):
            self.assertNotIn(gone, names)

    def test_how_short_click_counted_per_arm(self):
        """#978 S5 Test 3: die neue Kategorie wird je Arm gezählt, Raten unverändert."""
        write_how_export(self.base / "raw", [
            ("reopen-open-app", 1.0, True, "user: short click 0.1 s"),
            ("reopen-open-app", 2.0, False, "user: short click 0.1 s"),
            ("reopen-return", 3.0, True, "user: short click 0.1 s"),
            ("reopen-return-control", 4.0, True, "control: CGEvent at 1200,12"),
        ])
        how = self.summary.count_how([self.base / "raw"])
        self.assertEqual(how["open-app"], {"short-click": 2})
        self.assertEqual(how["return"], {"short-click": 1})
        self.assertEqual(how["control"], {"cgevent": 1})
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["open-app"], {"n": 2, "fails": 1, "rate": 0.5})
        text = self.run_script()
        self.assertIn("open-app: short-click 2", text)
        self.assertIn("return: short-click 1", text)
        self.assertNotIn("menubar-root", text)

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

    def test_user_arms_click_short_without_fallback(self):
        """#978 S5: Nutzerarme klicken kurz (0,1 s) über `shortClick`, ohne Rückfall auf statusItem.click().
        Kommentare zählen nicht."""
        def body(name):
            match = re.search(rf"func {name}\(.*?\n    \}}\n", self.text, re.S)
            self.assertIsNotNone(match, f"fehlt: func {name}")
            return re.sub(r"//.*$", "", match.group(0), flags=re.M)
        self.assertIn("shortClick(", body("assertSymbolOpensPanelWithOneClick"))
        self.assertIn("click(forDuration: 0.1", body("shortClick"))
        self.assertNotIn("statusItem.click()", body("shortClick"))
        self.lacks("frontmostRootClick")


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


# #978 S3 v4: Haltedauer-Probe. So schreibt `testHoldDurationProbe` den Anhang je Klick (Spec, Implementation Details 3).
def hold_text(d: float, clicked_at: float, opened: bool, monitor) -> str:
    monitor_line = "monitor saw nothing" if monitor is None else f"monitor hold: {monitor:.3f}"
    return (f"click: {clicked_at:.3f} (seconds since 1970)\n"
            f"d: {d:.1f}\n"
            f"result: {'open' if opened else 'closed'}\n"
            f"{monitor_line}\n")


def write_hold_export(folder: Path, clicks: list[tuple[float, float, bool, object]]) -> None:
    """Exportordner mit Halte-Anhängen `mac-gallery-hold-<d>-<n>-click` (d, Klickzeit, offen, Monitor-Dauer)."""
    folder.mkdir(parents=True, exist_ok=True)
    attachments = []
    for index, (d, at, opened, monitor) in enumerate(clicks):
        file_name = f"{index:04d}-hold.txt"
        (folder / file_name).write_text(hold_text(d, at, opened, monitor))
        attachments.append({"exportedFileName": file_name,
                            "suggestedHumanReadableName": f"mac-gallery-hold-{d:.1f}-{index}-click_0_{index:04d}.txt"})
    manifest = [{"testIdentifier": "MacGalleryTests/testHoldDurationProbe()", "attachments": attachments}]
    (folder / "manifest.json").write_text(json.dumps(manifest))


# Klick 1 um CLICK_FAIL: key nach 0,2 s, Maus hoch (global, type=2) nach 1,13 s → Log-Dauer key → Maus hoch 0,93 s.
# Klick 2 um CLICK_FAIL + 10: key nach 0,1 s, Maus hoch (lokal) nach 0,2 s → 0,10 s.
HOLD_LOG = """\
Timestamp               Ty Process[PID:TID]
2025-11-23 12:13:20.200 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=type=1,window=88,target=10920,source=0,time=1 active=true keyWindow=true front=x policy=accessory stack=a
2025-11-23 12:13:21.130 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] monitor global type=2 window=0 time=2
2025-11-23 12:13:21.150 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel resign window=MenuBarExtraWindow<AnyView> event=2 cg=nil active=false keyWindow=false front=x policy=accessory stack=b
2025-11-23 12:13:30.100 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=nil active=true keyWindow=true front=x policy=accessory stack=c
2025-11-23 12:13:30.200 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] monitor local type=2 window=88 time=3
"""


class HoldProbeSummaryTests(unittest.TestCase):
    """#978 S3 v4 AC-1, AC-7, AC-8: Arme hold-1.0/hold-0.1, key → Maus hoch, Monitor gegen Log, Entscheidungsregel."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)

    def run_script(self, log_text="", *extra):
        log = self.base / "panel.log"
        log.write_text(log_text)
        out = self.base / "summary.md"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--raw", str(self.base / "raw"), "--log", str(log), "--out", str(out),
             *extra], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out.read_text()

    def test_arm_of_hold_labels(self):
        self.assertEqual(self.summary.arm_of("mac-gallery-hold-1.0-3-click_0_0003.txt"), "hold-1.0")
        self.assertEqual(self.summary.arm_of("mac-gallery-hold-0.1-4-click_0_0004.txt"), "hold-0.1")
        self.assertIn("hold-1.0", self.summary.ARMS)
        self.assertIn("hold-0.1", self.summary.ARMS)

    def test_arm_of_hold_names_split_by_xcresulttool(self):
        # Reale Namen aus Lauf 45602877961: xcresulttool trennt „1.0“/„0.1“ am Punkt wie eine Dateiendung.
        arm_of = self.summary.arm_of
        self.assertEqual(arm_of("mac-gallery-hold-1_0_CE05AC11-ACA1-40C0-82D1-B30E06E74FF7.0-0-click"), "hold-1.0")
        self.assertEqual(arm_of("mac-gallery-hold-0_0_059B0C45-B911-4D47-A029-24FCF9285BB4.1-1-click"), "hold-0.1")
        self.assertIsNone(arm_of("mac-gallery-panel-hold-1_0_CE05AC11-ACA1-40C0-82D1-B30E06E74FF7.0-0-hierarchy"))

    def test_parse_hold(self):
        self.assertEqual(self.summary.parse_hold(hold_text(1.0, 12.5, False, 0.95)),
                         {"d": 1.0, "clicked_at": 12.5, "open": False, "monitor": 0.95})
        self.assertEqual(self.summary.parse_hold(hold_text(0.1, 13.0, True, None)),
                         {"d": 0.1, "clicked_at": 13.0, "open": True, "monitor": None})

    def test_counts_per_hold_arm(self):
        """Test 1: 20 Klicks 1,0 s alle zu, 20 Klicks 0,1 s alle offen."""
        clicks = [(1.0, float(i), False, 1.0) for i in range(20)] + [(0.1, 100.0 + i, True, 0.1) for i in range(20)]
        write_hold_export(self.base / "raw", clicks)
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["hold-1.0"], {"n": 20, "fails": 20, "rate": 1.0})
        self.assertEqual(counts["hold-0.1"], {"n": 20, "fails": 0, "rate": 0.0})
        self.assertEqual(counts["return"], {"n": 0, "fails": 0, "rate": None})
        text = self.run_script("", "--expected", "20", "--arms", "hold-1.0,hold-0.1")
        self.assertIn("| hold-1.0 | 20 | 20 | 100.0 % |", text)
        self.assertIn("| hold-0.1 | 20 | 0 | 0.0 % |", text)
        self.assertNotIn("erwartet", text)

    def test_hold_clicks_do_not_count_as_reopen(self):
        write_hold_export(self.base / "raw", [(1.0, 1.0, False, 1.0)])
        counts = self.summary.count_arms([self.base / "raw"])
        for arm in ("return", "open-app", "control"):
            self.assertEqual(counts[arm]["n"], 0, arm)

    def test_key_to_mouse_up_from_panel_log(self):
        events = self.summary.parse_panel_log(HOLD_LOG)
        self.assertAlmostEqual(self.summary.key_to_mouse_up(CLICK_FAIL, events), 0.93, places=2)
        self.assertAlmostEqual(self.summary.key_to_mouse_up(CLICK_FAIL + 10, events), 0.10, places=2)
        self.assertIsNone(self.summary.key_to_mouse_up(CLICK_FAIL + 100, events))

    def test_monitor_against_log(self):
        """Test 2: Log 0,93 s gegen Monitor 0,95 s stimmt überein; ein Klick ohne Monitorwert wird ausgewiesen."""
        write_hold_export(self.base / "raw", [(1.0, CLICK_FAIL, False, 0.95), (0.1, CLICK_FAIL + 10, True, None)])
        rows = self.summary.hold_rows([self.base / "raw"], self.summary.parse_panel_log(HOLD_LOG))
        self.assertEqual(len(rows), 2)
        first, second = sorted(rows, key=lambda r: r["clicked_at"])
        self.assertEqual(first["arm"], "hold-1.0")
        self.assertAlmostEqual(first["log"], 0.93, places=2)
        self.assertEqual(first["monitor"], 0.95)
        self.assertEqual(first["agreement"], "match")
        self.assertEqual(second["agreement"], "monitor saw nothing")
        self.assertEqual(self.summary.agreement(0.95, 0.60), "mismatch")
        self.assertEqual(self.summary.agreement(0.95, None), "no log")
        text = self.run_script(HOLD_LOG, "--arms", "hold-1.0,hold-0.1")
        self.assertIn("Monitor sah Ereignisse: 1 von 2", text)
        self.assertIn("monitor saw nothing: 1", text)
        self.assertIn("Übereinstimmung Monitor/Log: 1", text)

    def test_decision_rule(self):
        """Test 4 (lokal): Regel aus Spec Punkt 6."""
        def counts(n1, z1, n2, z2):
            return {"hold-1.0": {"n": n1, "fails": z1, "rate": z1 / n1 if n1 else None},
                    "hold-0.1": {"n": n2, "fails": z2, "rate": z2 / n2 if n2 else None}}
        self.assertEqual(self.summary.decision(counts(20, 19, 20, 0)), "bestanden")
        self.assertEqual(self.summary.decision(counts(20, 18, 20, 0)), "nicht bestanden")
        self.assertEqual(self.summary.decision(counts(20, 20, 20, 1)), "nicht bestanden")
        self.assertEqual(self.summary.decision(counts(19, 19, 20, 0)), "zu wenig Klicks")
        write_hold_export(self.base / "raw", [(1.0, float(i), False, 1.0) for i in range(20)]
                          + [(0.1, 100.0 + i, True, 0.1) for i in range(20)])
        self.assertIn("Entscheidung: bestanden", self.run_script("", "--arms", "hold-1.0,hold-0.1"))

    def test_reopen_report_has_no_hold_section(self):
        write_export(self.base / "raw", [("reopen-return", 1.0, True), ("reopen-open-app", 2.0, True)])
        text = self.run_script()
        self.assertNotIn("Entscheidung:", text)


# #978 S5: kurze Klicks. Klick A um SHORT_A: key nach 0,15 s, das nächste Maus-hoch erst 12 s später (gehört zu einem
# anderen Vorgang). Klick B um SHORT_B: key nach 0,2 s, Maus hoch 0,93 s nach key.
SHORT_A = 1763900000.000
SHORT_B = 1763900100.000
SHORT_LOG = """\
Timestamp               Ty Process[PID:TID]
2025-11-23 12:13:20.150 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=nil active=true keyWindow=true front=x policy=accessory stack=a
2025-11-23 12:13:32.150 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] monitor local type=2 window=88 time=2
2025-11-23 12:15:00.200 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] panel key window=MenuBarExtraWindow<AnyView> event=1 cg=nil active=true keyWindow=true front=x policy=accessory stack=b
2025-11-23 12:15:01.130 Df LooseEnds[10920:83c2] [com.henning.looseends:MenuBarPanel] monitor global type=2 window=0 time=3
"""


class ShortClickSummaryTests(unittest.TestCase):
    """#978 S5 Test 1, 2 und AC-5: Maus-hoch nur im 3-s-Monitorfenster nach `key`, sonst „kurz (kein Maus-hoch)“."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)

    def test_no_pairing_with_late_mouse_up(self):
        """Test 1: ein Maus-hoch 12 s nach key gehört nicht zum Klick."""
        events = self.summary.parse_panel_log(SHORT_LOG)
        self.assertIsNone(self.summary.key_to_mouse_up(SHORT_A, events))
        self.assertEqual(self.summary.hold_of(SHORT_A, events), self.summary.SHORT)
        self.assertEqual(self.summary.SHORT, "kurz (kein Maus-hoch)")

    def test_mouse_up_inside_window_gives_seconds(self):
        """Test 2: Maus hoch 0,93 s nach key ist die Haltedauer."""
        events = self.summary.parse_panel_log(SHORT_LOG)
        self.assertAlmostEqual(self.summary.key_to_mouse_up(SHORT_B, events), 0.93, places=2)
        self.assertAlmostEqual(self.summary.hold_of(SHORT_B, events), 0.93, places=2)

    def test_click_without_key_has_no_hold(self):
        self.assertIsNone(self.summary.hold_of(SHORT_A + 1000, self.summary.parse_panel_log(SHORT_LOG)))

    def test_report_names_hold_per_click(self):
        """AC-5: der Bericht nennt je Wiederöffnungsklick die Haltedauer oder „kurz (kein Maus-hoch)“."""
        write_how_export(self.base / "raw", [("reopen-return", SHORT_A, True, "user: short click 0.1 s"),
                                             ("reopen-open-app", SHORT_B, False, "user: short click 0.1 s")])
        log = self.base / "panel.log"
        log.write_text(SHORT_LOG)
        out = self.base / "summary.md"
        result = subprocess.run([sys.executable, str(SCRIPT), "--raw", str(self.base / "raw"), "--log", str(log),
                                 "--out", str(out)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        text = out.read_text()
        self.assertIn("Haltedauer je Klick", text)
        self.assertRegex(text, r"\| 1763900000\.000 \| return \| open \| kurz \(kein Maus-hoch\) \|")
        self.assertRegex(text, r"\| 1763900100\.000 \| open-app \| not open \| 0\.930 s \|")
        self.assertNotIn("12.000 s", text)


class HoldProbeSourceTests(SourceCheck):
    """#978 S3 v4 AC-2 bis AC-6 am Quelltext."""

    def gallery(self):
        self.text = GALLERY_TESTS.read_text()

    def probe_body(self):
        self.gallery()
        match = re.search(r"func testHoldDurationProbe\(\).*?\n    \}\n", self.text, re.S)
        self.assertIsNotNone(match, "fehlt: func testHoldDurationProbe")
        return re.sub(r"//.*$", "", match.group(0), flags=re.M)

    def test_probe_clicks_with_duration_on_same_coordinate(self):
        """AC-2: click(forDuration:thenDragTo:) mit 1,0 s und 0,1 s im Wechsel."""
        self.probe_body()
        self.has("click(forDuration:")
        self.has("thenDragTo:")
        self.matches(r"\[\s*1\.0\s*,\s*0\.1\s*\]")

    def test_probe_guarded_by_env(self):
        """AC-3: ohne LE_PANEL_HOLD_PROBE übersprungen, wie der Kontrollarm."""
        body = self.probe_body()
        self.assertIn("LE_PANEL_HOLD_PROBE", body)
        self.assertIn("XCTSkip(", body)

    def test_attachment_lines_and_monitor(self):
        """AC-4: Anhang nennt d, Ergebnis und Monitor-Dauer oder `monitor saw nothing`."""
        self.gallery()
        for needle in ("addGlobalMonitorForEvents", ".leftMouseDown", ".leftMouseUp", "monitor saw nothing",
                       "monitor hold: ", '"d: ', "result: ", '"mac-gallery-hold-'):
            self.has(needle)

    def test_workflow_input_halteprobe(self):
        """AC-5: Eingabe halteprobe setzt die Variable und wählt nur den Probetest; die Reopen-Tests bleiben der Standard."""
        self.text = WORKFLOW.read_text()
        for needle in ("halteprobe:", "TEST_RUNNER_LE_PANEL_HOLD_PROBE=1",
                       "-only-testing:LooseEndsUITests/MacGalleryTests/testHoldDurationProbe", "hold-1.0,hold-0.1",
                       "testMenuBarReopensAfterReturnWithOneClick"):
            self.has(needle)

    def test_required_job_and_reopen_tests_unchanged(self):
        """AC-6: der Pflicht-Job setzt die Probe nie, die drei Wiederöffnungstests gibt es weiter."""
        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text()
        self.assertNotIn("LE_PANEL_HOLD_PROBE", ci)
        self.gallery()
        for name in ("testMenuBarReopensAfterReturnWithOneClick", "testMenuBarReopensAfterOpenAppWithOneClick",
                     "testMenuBarReopensAfterReturnWithControlClick"):
            self.has(f"func {name}(")


def retry_export(folder: Path, clicks: list[tuple[str, float, bool, object]]) -> None:
    """Wie `write_how_export`; ein vierter Wert ungleich None ist die gelesene Haltedauer des ersten Klicks, und der
    Anhang trägt dann die Zeile `retry: hold X s` wie der zweite Klick aus `assertSymbolOpensPanelWithOneClick` (v6)."""
    folder.mkdir(parents=True, exist_ok=True)
    tests = {}
    for index, (label, at, opened, retry) in enumerate(clicks):
        file_name = f"{index:04d}-click.txt"
        lines = click_text(at, opened).splitlines()
        extra = [f"retry: hold {retry:.3f} s"] if retry is not None else []
        (folder / file_name).write_text("\n".join([lines[0], "how: user: short click 0.1 s", *extra, *lines[1:]]) + "\n")
        tests.setdefault(f"MacGalleryTests/test-{label}()", []).append({
            "exportedFileName": file_name,
            "suggestedHumanReadableName": f"mac-gallery-{label}-click_0_{index:04d}.txt",
        })
    manifest = [{"testIdentifier": k, "attachments": v} for k, v in tests.items()]
    (folder / "manifest.json").write_text(json.dumps(manifest))


class RetrySummaryTests(unittest.TestCase):
    """#978 S5 v6, Spec Test 1 bis 3 und AC-1: der zweite Klick nach einer gelesenen Haltedauer ab 0,4 s trägt
    `retry: hold X s`; er entscheidet die Iteration, zählt nicht als eigene Iteration und wird ausgewiesen."""

    def setUp(self):
        self.summary = load_summary()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)

    def report(self):
        log = self.base / "panel.log"
        log.write_text("")
        out = self.base / "summary.md"
        result = subprocess.run([sys.executable, str(SCRIPT), "--raw", str(self.base / "raw"), "--log", str(log),
                                 "--out", str(out)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out.read_text()

    def test_parse_retry(self):
        text = "click: 1.000 (seconds since 1970)\nretry: hold 0.616 s\nafter: 3.40 s, panel open\n"
        self.assertAlmostEqual(self.summary.parse_retry(text), 0.616, places=3)
        self.assertIsNone(self.summary.parse_retry("click: 1.000 (seconds since 1970)\nafter: 3.40 s, panel open\n"))

    def test_retry_open_is_not_red_and_is_shown(self):
        """Test 1: erster Klick zu, zweiter mit `retry: hold 0.616 s` offen → eine Iteration, nicht rot, ausgewiesen."""
        retry_export(self.base / "raw", [("reopen-open-app", 100.0, False, None),
                                         ("reopen-open-app", 115.0, True, 0.616),
                                         ("reopen-return", 200.0, True, None)])
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["open-app"], {"n": 1, "fails": 0, "rate": 0.0})
        self.assertEqual(counts["return"], {"n": 1, "fails": 0, "rate": 0.0})
        found = self.summary.retries([self.base / "raw"])
        self.assertEqual(len(found["open-app"]), 1)
        self.assertAlmostEqual(found["open-app"][0]["hold"], 0.616, places=3)
        self.assertTrue(found["open-app"][0]["open"])
        self.assertEqual(found["return"], [])
        text = self.report()
        self.assertIn("## Wiederholungen", text)
        self.assertRegex(text, r"\| 115\.000 \| open-app \| 0\.616 s \| open \|")
        self.assertRegex(text, r"\| open-app \| 1 \| 0 \| 0\.0 % \|")

    def test_retry_closed_is_red(self):
        """Test 2: auch der zweite Klick zu → die Iteration zählt als rot, der zweite Klick steht im Bericht."""
        retry_export(self.base / "raw", [("reopen-return", 100.0, False, None),
                                         ("reopen-return", 115.0, False, 0.71)])
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["return"], {"n": 1, "fails": 1, "rate": 1.0})
        found = self.summary.retries([self.base / "raw"])
        self.assertEqual(len(found["return"]), 1)
        self.assertFalse(found["return"][0]["open"])
        self.assertRegex(self.report(), r"\| 115\.000 \| return \| 0\.710 s \| not open \|")

    def test_without_retry_counts_unchanged(self):
        """Test 3: ohne `retry` keine Wiederholung, die Zähler wie bisher."""
        retry_export(self.base / "raw", [("reopen-return", 100.0, True, None),
                                         ("reopen-return", 200.0, False, None),
                                         ("reopen-open-app", 300.0, True, None)])
        counts = self.summary.count_arms([self.base / "raw"])
        self.assertEqual(counts["return"], {"n": 2, "fails": 1, "rate": 0.5})
        self.assertEqual(counts["open-app"], {"n": 1, "fails": 0, "rate": 0.0})
        self.assertEqual(self.summary.retries([self.base / "raw"]),
                         {"return": [], "open-app": [], "control": []})
        text = self.report()
        self.assertIn("## Wiederholungen", text)
        self.assertIn("- return: 0", text)
        self.assertIn("- open-app: 0", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
