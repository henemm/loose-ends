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

    def test_cancel_test_declines_server_recognition_up_front(self):
        source = (ROOT / "LooseEndsUITests" / "CaptureCancelCrashTests.swift").read_text()
        # `<false/>`, not `NO`: SpeechCapture reads `object(forKey:) as? Bool`, and `NO` arrives as a string.
        self.assertIn('"-speechServerRecognitionAllowed", "<false/>"', source)


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
