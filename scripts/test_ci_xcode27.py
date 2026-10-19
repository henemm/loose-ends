"""Tests für die CI auf Xcode 27.0 ohne Absenkung (#178).

Aufruf: python3 scripts/test_ci_xcode27.py
Die Schritte laufen gegen nachgebaute `xcodebuild`/`xcrun`; ob das Image sie wirklich so liefert,
zeigt nur der echte CI-Lauf.
"""
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
GITHUB = ROOT / ".github"
ACTION = GITHUB / "actions" / "select-xcode-27" / "action.yml"
CI = GITHUB / "workflows" / "ci.yml"
STRESS = GITHUB / "workflows" / "speech-stress.yml"
ACTION_REF = "./.github/actions/select-xcode-27"
RUNTIME_27 = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
RUNTIME_26 = "com.apple.CoreSimulator.SimRuntime.iOS-26-0"


def load(path):
    return yaml.safe_load(path.read_text())


def jobs():
    """Alle Jobs aus ci.yml und speech-stress.yml, als (Datei, Job-Schlüssel, Job)."""
    return [(p.name, key, job) for p in (CI, STRESS) for key, job in load(p)["jobs"].items()]


def step_named(job, prefix):
    return next(s for s in job["steps"] if s.get("name", "").startswith(prefix))


def write_exe(folder, name, body):
    path = folder / name
    path.write_text("#!/bin/bash\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


def run_bash(script, fakes, extra_env=None):
    env = {**os.environ, "PATH": f"{fakes}:{os.environ['PATH']}", **(extra_env or {})}
    return subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script],
                          capture_output=True, text=True, env=env)


class SelectXcodeAction(unittest.TestCase):
    def run_check(self, reported):
        script = load(ACTION)["runs"]["steps"][0]["run"]
        with tempfile.TemporaryDirectory() as tmp:
            fakes = Path(tmp)
            write_exe(fakes, "sudo", 'exec "$@"\n')
            write_exe(fakes, "xcode-select", 'echo "xcode-select $*" >> "$CALLS"\n')
            write_exe(fakes, "xcodebuild", f'printf "{reported}\\nBuild version 27A266a\\n"\n')
            calls = fakes / "calls"
            result = run_bash(script, fakes, {"CALLS": str(calls)})
            return result, calls.read_text() if calls.exists() else ""

    def test_selects_fixed_xcode_27_app(self):
        _, calls = self.run_check("Xcode 27.0")
        self.assertIn("-s /Applications/Xcode_27.app", calls)

    def test_accepts_xcode_27_0(self):
        result, _ = self.run_check("Xcode 27.0")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rejects_other_version(self):
        for reported in ("Xcode 26.6", "Xcode 27.2"):
            result, _ = self.run_check(reported)
            self.assertEqual(result.returncode, 1, reported)
            self.assertIn("::error::", result.stdout + result.stderr, reported)


class Workflows(unittest.TestCase):
    def test_every_job_runs_on_xcode_27_with_the_action(self):
        for name, key, job in jobs():
            self.assertEqual(job["runs-on"], "xcode-27", f"{name}:{key}")
            uses = [s.get("uses") for s in job["steps"]]
            self.assertIn(ACTION_REF, uses, f"{name}:{key}")

    def test_no_lowering_anywhere_in_github(self):
        result = subprocess.run(["grep", "-rnE", r"sed -i|26\.0|macos-26|project\.yml", str(GITHUB)],
                                capture_output=True, text=True)
        self.assertEqual(result.stdout, "", "Absenkung noch vorhanden")

    def test_unit_job_runs_every_script_test(self):
        """#185: every scripts/test_*.py runs in CI, in one step, before Xcode."""
        steps = load(CI)["jobs"]["unit-tests"]["steps"]
        step = step_named(load(CI)["jobs"]["unit-tests"], "Script tests")
        self.assertIn("unittest discover -s scripts -p 'test_*.py'", step["run"])
        names = [s.get("name") for s in steps]
        self.assertLess(names.index("Script tests"), names.index("Build and test"))

    def test_check_names_unchanged(self):
        names = {job["name"] for _, _, job in jobs()}
        for expected in ("Unit Tests (macOS destination)", "Build (iOS Simulator)", "UI Smoke (iOS Simulator)"):
            self.assertIn(expected, names)

    def test_ui_smoke_has_a_diagnosis_step_that_never_fails(self):
        job = load(CI)["jobs"]["ui-smoke"]
        step = step_named(job, "Diagnose")
        self.assertTrue(step.get("continue-on-error"), "Diagnose darf den Lauf nie abbrechen")
        self.assertIn("xcodebuild -version", step["run"])

    def test_workflows_wait_for_the_simulator_to_finish_booting(self):
        for workflow, key, first_use in ((CI, "ui-smoke", "Run UI smoke tests"), (STRESS, "stress", "Build for testing")):
            steps = load(workflow)["jobs"][key]["steps"]
            names = [s.get("name") for s in steps]
            wait = step_named(load(workflow)["jobs"][key], "Wait until the simulator")
            self.assertIn('simctl bootstatus "$SIM_UDID" -b', wait["run"], workflow.name)
            self.assertLess(names.index(wait["name"]), names.index(first_use), workflow.name)
            self.assertLess(names.index(step_named(load(workflow)["jobs"][key], "Pick a simulator")["name"]),
                            names.index(wait["name"]), workflow.name)

    def test_ui_smoke_lets_the_simulator_settle_and_runs_without_parallel_clones(self):
        job = load(CI)["jobs"]["ui-smoke"]
        names = [s.get("name") for s in job["steps"]]
        settle = step_named(job, "Let the simulator settle")
        self.assertTrue(settle.get("continue-on-error"), "Das Abwarten darf den Lauf nie abbrechen")
        self.assertLessEqual(settle.get("timeout-minutes", 999), 5)
        self.assertGreater(names.index(settle["name"]), names.index(step_named(job, "Wait until the simulator")["name"]))
        self.assertLess(names.index(settle["name"]), names.index("Run UI smoke tests"))
        self.assertIn("-parallel-testing-enabled NO", step_named(job, "Run UI smoke tests")["run"])
        self.assertIn("com.apple.PosterBoard", settle["run"])
        self.assertIn("|| true", settle["run"], "Jeder Abschaltversuch darf scheitern")

    def test_unit_job_prints_measurement_reports_into_its_own_log(self):
        job = load(CI)["jobs"]["unit-tests"]
        names = [s.get("name") for s in job["steps"]]
        step = step_named(job, "Print measurement reports")
        self.assertTrue(step.get("continue-on-error"), "Der Bericht darf den Lauf nie abbrechen")
        self.assertEqual(step.get("if"), "always()")
        self.assertIn("-REPORT BEGIN", step["run"])
        self.assertIn("-REPORT END", step["run"])
        self.assertGreater(names.index(step["name"]), names.index("Build and test"))
        self.assertLess(names.index(step["name"]), names.index("Upload test results"))


class MacGallery(unittest.TestCase):
    """#511: the Mac app photographed in CI, never on Henning's Mac."""

    def job(self):
        return load(CI)["jobs"]["mac-gallery"]

    def names(self):
        return [s.get("name") for s in self.job()["steps"]]

    def test_job_runs_on_xcode_27_and_never_fails_silently(self):
        job = self.job()
        self.assertEqual(job["name"], "Mac Gallery (macOS)")
        self.assertEqual(job["runs-on"], "xcode-27")
        self.assertIn(ACTION_REF, [s.get("uses") for s in job["steps"]])
        self.assertNotIn("continue-on-error", job, "Eine still scheiternde Galerie ist kein Nachweis")

    def test_runs_only_the_mac_gallery_and_the_click_test_on_the_mac_with_ad_hoc_signing(self):
        run = step_named(self.job(), "Run Mac gallery")["run"]
        self.assertIn("-destination 'platform=macOS'", run)
        self.assertIn("-only-testing:LooseEndsUITests/MacGalleryTests", run)
        # #544: the detail click test runs next to the gallery; still never all UI tests.
        self.assertIn("-only-testing:LooseEndsUITests/MacDetailClickTests", run)
        self.assertEqual(run.count("-only-testing:"), 2, "nur Galerie und Klick-Test, nicht alle UI-Tests")
        self.assertIn("-resultBundlePath MacGallery.xcresult", run)
        for arg in ("CODE_SIGN_IDENTITY=-", "CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM=", "CODE_SIGN_ENTITLEMENTS="):
            self.assertIn(arg, run.split(), arg)

    def test_automation_mode_is_enabled_before_the_test(self):
        names = self.names()
        step = step_named(self.job(), "Enable UI automation")
        self.assertIn("sudo automationmodetool enable-automationmode-without-authentication", step["run"])
        self.assertIn("DevToolsSecurity -enable", step["run"])
        self.assertLess(names.index(step["name"]), names.index(step_named(self.job(), "Run Mac gallery")["name"]))

    def test_diagnosis_export_and_upload_run_after_a_failure(self):
        job, names = self.job(), self.names()
        test_at = names.index(step_named(job, "Run Mac gallery")["name"])
        diagnose = step_named(job, "Diagnose UI automation")
        self.assertTrue(diagnose.get("continue-on-error"), "Die Diagnose darf den Lauf nie abbrechen")
        for prefix in ("Diagnose UI automation", "Export Mac gallery", "Upload Mac gallery"):
            step = step_named(job, prefix)
            self.assertEqual(step.get("if"), "always()", prefix)
            self.assertGreater(names.index(step["name"]), test_at, prefix)
        upload = step_named(job, "Upload Mac gallery")
        self.assertEqual(upload["with"]["name"], "MacGallery")
        self.assertEqual(upload["with"]["path"], "MacGallery")

    def test_export_keeps_only_mac_gallery_attachments(self):
        script = step_named(self.job(), "Export Mac gallery")["run"]
        manifest = [{"attachments": [
            {"suggestedHumanReadableName": "mac-gallery-light-1-start_0_AB12.png", "exportedFileName": "a.png"},
            {"suggestedHumanReadableName": "mac-gallery-light-window-size_0_CD34.txt", "exportedFileName": "b.txt"},
            {"suggestedHumanReadableName": "gallery-light-1-start_0_EF56.png", "exportedFileName": "c.png"},
            {"suggestedHumanReadableName": "Screenshot at failure_0_GH78.png", "exportedFileName": "d.png"},
        ]}]
        with tempfile.TemporaryDirectory() as tmp:
            fakes, work = Path(tmp) / "bin", Path(tmp) / "work"
            fakes.mkdir()
            work.mkdir()
            write_exe(fakes, "xcrun", """
out=""; while [ $# -gt 0 ]; do [ "$1" = "--output-path" ] && out="$2"; shift; done
cp "$FIXTURE"/* "$out"/
""")
            fixture = Path(tmp) / "fixture"
            fixture.mkdir()
            (fixture / "manifest.json").write_text(json.dumps(manifest))
            for name in ("a.png", "b.txt", "c.png", "d.png"):
                (fixture / name).write_text(name)
            result = run_bash(f"cd {work}\n{script}", fakes, {"FIXTURE": str(fixture)})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(sorted(p.name for p in (work / "MacGallery").iterdir()),
                             ["mac-gallery-light-1-start.png", "mac-gallery-light-window-size.txt"])

    def test_ui_smoke_neither_runs_nor_exports_the_mac_gallery(self):
        smoke = load(CI)["jobs"]["ui-smoke"]
        self.assertNotIn("MacGallery", yaml.safe_dump(smoke))
        self.assertEqual(step_named(smoke, "Upload design gallery")["with"]["name"], "DesignGallery")

    MAC_SOURCES = ("MacGalleryTests.swift", "MacUITestSupport.swift", "MacDetailClickTests.swift")

    def mac_source(self, name):
        lines = [l for l in (ROOT / "LooseEndsUITests" / name).read_text().splitlines()
                 if l.strip() and not l.lstrip().startswith("//")]
        self.assertEqual(lines[0].strip(), "#if os(macOS)", name)
        self.assertEqual(lines[-1].strip(), "#endif", name)
        return "\n".join(lines)

    def test_gallery_source_is_mac_only(self):
        # The helpers moved to MacUITestSupport with #544; gallery and click test share them.
        sources = {name: self.mac_source(name) for name in self.MAC_SOURCES}
        combined = "\n".join(sources.values())
        for name in ("mac-gallery-", "window-size", "viewRow_new", "startCaptureField", "detailRawTextMarker"):
            self.assertIn(name, combined, name)
        self.assertIn(".screenshot()", combined)
        for name, source in sources.items():
            self.assertNotIn("app.screenshot()", source, f"{name}: das Hauptfenster, nicht der ganze Bildschirm")
        for name in ("MacGalleryTests.swift", "MacDetailClickTests.swift"):
            self.assertIn("mac-gallery-", sources[name], f"{name} liefert Bilder ins Artefakt MacGallery")

    def test_click_test_clicks_the_fields_and_both_pickers(self):
        """#544: the click test reaches Note, subtask, File and Photo; the gallery only photographs ("Add more" gone, #560)."""
        source = self.mac_source("MacDetailClickTests.swift")
        for identifier in ("noteField", "subtaskTextField", "addFileButton", "addPhotoButton"):
            self.assertIn(identifier, source, identifier)
        self.assertIn("hasKeyboardFocus", source, "der Klick muss den Fokus setzen, nicht nur treffen")

    def test_claude_md_names_the_mac_gallery(self):
        text = (ROOT / "CLAUDE.md").read_text()
        for name in ("Mac Gallery (macOS)", "MacGallery", "mac-gallery-"):
            self.assertTrue(name in text, f"CLAUDE.md nennt {name} nicht")


class PickSimulator(unittest.TestCase):
    def pick(self, workflow, key, devices):
        script = step_named(load(workflow)["jobs"][key], "Pick a simulator")["run"]
        with tempfile.TemporaryDirectory() as tmp:
            fakes = Path(tmp)
            (fakes / "devices.json").write_text(json.dumps({"devices": devices}))
            write_exe(fakes, "xcrun", """
if [ "$*" = "simctl list devices available -j" ]; then cat "$FAKES/devices.json"
elif [ "$*" = "simctl list devices available" ]; then cat "$FAKES/devices.json"
elif [ "$1 $2" = "simctl boot" ]; then exit 0
else echo "unexpected xcrun $*" >&2; exit 2; fi
""")
            env_file = fakes / "github_env"
            env_file.touch()
            result = run_bash(script, fakes, {"FAKES": str(fakes), "GITHUB_ENV": str(env_file)})
            return result, env_file.read_text()

    @staticmethod
    def iphone(name, udid):
        return [{"name": name, "udid": udid, "state": "Shutdown", "isAvailable": True}]

    def test_picks_iphone_17_on_ios_27_0(self):
        devices = {RUNTIME_26: self.iphone("iPhone 17", "OLD"), RUNTIME_27: self.iphone("iPhone 17", "NEW")}
        for workflow, key in ((CI, "ui-smoke"), (STRESS, "stress")):
            result, env = self.pick(workflow, key, devices)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("SIM_UDID=NEW", env, workflow.name)

    def test_fails_without_iphone_17_on_ios_27_0(self):
        devices = {RUNTIME_26: self.iphone("iPhone 17", "OLD"), RUNTIME_27: self.iphone("iPhone 16e", "OTHER")}
        for workflow, key in ((CI, "ui-smoke"), (STRESS, "stress")):
            result, env = self.pick(workflow, key, devices)
            self.assertNotEqual(result.returncode, 0, workflow.name)
            self.assertIn("::error::", result.stdout + result.stderr, workflow.name)
            self.assertNotIn("SIM_UDID", env, workflow.name)


class SpeechStressOnXcode27(unittest.TestCase):
    """Nachtrag 2026-10-06: Befunde aus Lauf 37415827670."""

    def test_stress_runs_skip_the_600_second_diagnostics(self):
        script = step_named(load(STRESS)["jobs"]["stress"], "Run CaptureCancelCrashTests")["run"]
        self.assertIn("test-without-building", script)
        self.assertIn("-collect-test-diagnostics never", script)

    def test_no_server_recognition_dialog_left_to_decline(self):
        # #64: recognition runs on the device only, so the dialog that could swallow the cancel tap
        # is gone, and with it the launch argument that declined it.
        capture = (ROOT / "LooseEnds" / "Speech" / "SpeechCapture.swift").read_text()
        self.assertNotIn("serverConsent", capture)
        self.assertNotIn("requiresOnDeviceRecognition", capture)
        source = (ROOT / "LooseEndsUITests" / "CaptureCancelCrashTests.swift").read_text()
        self.assertNotIn("-speechServerRecognitionAllowed", source)


class Sources(unittest.TestCase):
    def test_no_compiler_switch_left(self):
        result = subprocess.run(["grep", "-rn", "--include=*.swift", "compiler(>=6.4)",
                                 str(ROOT / "Shared"), str(ROOT / "LooseEnds"), str(ROOT / "Measurement")],
                                capture_output=True, text=True)
        self.assertEqual(result.stdout, "")

    def test_claude_md_describes_the_new_ci(self):
        text = (ROOT / "CLAUDE.md").read_text()
        self.assertIn("xcode-27", text.split("## Ship")[0])
        self.assertNotIn("lowers the deployment", text)
        self.assertIn("docs/reference/testflight.md", text.split("## Ship")[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
