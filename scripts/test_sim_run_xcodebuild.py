"""Tests für `run_xcodebuild` in sim.sh: Testläufe ohne Simulator-Diagnose (#298).

`xcodebuild test` sammelt nach dem Ergebnis per `simctl diagnose` Diagnosen und wartet darauf, im
Lauf zu #274 bis zu 19 Minuten. `-collect-test-diagnostics never` schaltet das ab, nur für `test`.

Aufruf: python3 -m unittest scripts/test_sim_run_xcodebuild.py
"""
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent


def run_xcodebuild_source():
    """Die Funktion wörtlich aus sim.sh, damit der Test das ausgelieferte Skript prüft."""
    text = (SCRIPTS / "sim.sh").read_text()
    match = re.search(r"(?ms)^run_xcodebuild\(\) \{.*?^\}", text)
    if match is None:
        raise AssertionError("run_xcodebuild() fehlt in scripts/sim.sh")
    return match.group(0)


class RunXcodebuildDiagnosticsTests(unittest.TestCase):

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        stubs = self.root / "stubs"
        stubs.mkdir()
        self.args_file = self.root / "xcodebuild-args"
        xcodebuild = stubs / "xcodebuild"
        xcodebuild.write_text(f'#!/bin/bash\nprintf "%s\\n" "$@" > "{self.args_file}"\n')
        xcodebuild.chmod(0o755)
        xcbeautify = stubs / "xcbeautify"
        xcbeautify.write_text("#!/bin/bash\ncat >/dev/null\n")
        xcbeautify.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{stubs}:/usr/bin:/bin")

    def xcodebuild_args(self, *args):
        script = "\n".join([
            "set -euo pipefail",
            f'PROJECT_DIR="{self.root}"',
            f'SESSION_DERIVED_DATA="{self.root}/DerivedData"',
            run_xcodebuild_source(),
            'run_xcodebuild "$@"',
        ])
        subprocess.run(["bash", "-c", script, "sim.sh", *args], env=self.env, check=True,
                       capture_output=True, text=True, timeout=30)
        return self.args_file.read_text().splitlines()

    def test_test_action_switches_off_diagnostics_collection(self):
        args = self.xcodebuild_args("test", "-project", "P.xcodeproj", "-only-testing:LooseEndsTests")
        self.assertIn("-collect-test-diagnostics", args)
        self.assertEqual(args[args.index("-collect-test-diagnostics") + 1], "never")
        self.assertEqual(args[0], "test")
        self.assertIn("-only-testing:LooseEndsTests", args)

    def test_build_action_keeps_its_arguments_unchanged(self):
        args = self.xcodebuild_args("build", "-project", "P.xcodeproj")
        self.assertNotIn("-collect-test-diagnostics", args)
        self.assertEqual(args[:3], ["build", "-project", "P.xcodeproj"])


class RunXcodebuildSilenceGuardTests(unittest.TestCase):
    """Stille-Wächter (#516): ein stummer xcodebuild hält die rechnerweite Sperre nicht unbegrenzt."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        self.stubs = self.root / "stubs"
        self.stubs.mkdir()
        self.derived = self.root / "DerivedData"
        (self.stubs / "xcbeautify").write_text("#!/bin/bash\ncat >/dev/null\n")
        (self.stubs / "xcbeautify").chmod(0o755)
        self.environment = dict(os.environ, PATH=f"{self.stubs}:/usr/bin:/bin",
                                LOOSEENDS_SILENCE_MAX="2", LOOSEENDS_SILENCE_POLL="1")

    def stub(self, body):
        path = self.stubs / "xcodebuild"
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_guarded(self, pipefail=True, timeout=15):
        released = self.root / "released"
        script = "\n".join([
            "set -euo pipefail" if pipefail else "set -eu",
            f'PROJECT_DIR="{self.root}"',
            f'SESSION_DERIVED_DATA="{self.derived}"',
            f"trap 'touch \"{released}\"' EXIT",
            run_xcodebuild_source(),
            "run_xcodebuild build -project P.xcodeproj",
            "echo REACHED_AFTER",
        ])
        proc = subprocess.Popen(["bash", "-c", script, "sim.sh"], env=self.environment, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            out, err = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.communicate()
            self.fail(f"der Lauf hängt nach {timeout} s weiter, der Wächter hat nicht eingegriffen")
        self.released = released.exists()
        return subprocess.CompletedProcess(proc.args, proc.returncode, out, err)

    def test_silent_xcodebuild_is_killed_after_deadline(self):
        self.stub(f'echo "letzte Zeile vor der Stille"\necho $$ > "{self.root}/pid"\nsleep 600 &\necho $! > "{self.root}/child"\nwait')
        result = self.run_guarded()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("REACHED_AFTER", result.stdout)
        pid = int((self.root / "pid").read_text())
        self.assertFalse(alive(pid), "der stumme xcodebuild lebt noch")
        child = int((self.root / "child").read_text())
        self.assertFalse(alive(child), "ein Kind des stummen xcodebuild lebt noch")

    def test_hang_detected_without_pipefail(self):
        self.stub("echo eins\nsleep 600")
        result = self.run_guarded(pipefail=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("REACHED_AFTER", result.stdout)

    def test_hang_message_names_deadline_last_line_and_simulator_service(self):
        self.stub('echo "IDESchemeActionSDKRecord letzte Zeile"\nsleep 600')
        err = self.run_guarded().stderr
        self.assertIn("abgebrochen", err)
        self.assertIn("hängt seit", err)
        self.assertIn("LOOSEENDS_SILENCE_MAX", err)
        self.assertIn("IDESchemeActionSDKRecord letzte Zeile", err)
        self.assertIn("CoreSimulatorService", err)

    def test_lock_released_after_hang(self):
        self.stub("echo eins\nsleep 600")
        self.run_guarded()
        self.assertTrue(self.released, "der EXIT-Trap lief nicht, die Sperre bliebe stehen")

    def test_other_session_xcodebuild_survives(self):
        foreign = self.root / "foreign"
        foreign.mkdir()
        (foreign / "xcodebuild").write_text("#!/bin/bash\nsleep 600\n")
        (foreign / "xcodebuild").chmod(0o755)
        other = subprocess.Popen([str(foreign / "xcodebuild"), "-derivedDataPath", str(self.root / "andere-sitzung")],
                                 start_new_session=True)
        self.addCleanup(os.killpg, other.pid, signal.SIGKILL)
        self.stub("echo eins\nsleep 600")
        self.run_guarded()
        self.assertIsNone(other.poll(), "der xcodebuild einer anderen Sitzung wurde beendet")

    def test_talkative_run_is_not_aborted(self):
        self.stub("for i in 1 2 3 4 5; do echo zeile $i; sleep 1; done")
        result = self.run_guarded()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("REACHED_AFTER", result.stdout)
        self.assertNotIn("abgebrochen", result.stderr)

    def test_no_leftovers_after_normal_run(self):
        self.stub("echo fertig")
        result = self.run_guarded()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.derived.glob("*.hung")), [])
        time.sleep(1.5)
        ps = subprocess.run(["pgrep", "-f", str(self.derived)], capture_output=True, text=True)
        self.assertEqual(ps.stdout.strip(), "", "ein Wächterprozess läuft weiter")


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


if __name__ == "__main__":
    unittest.main()
