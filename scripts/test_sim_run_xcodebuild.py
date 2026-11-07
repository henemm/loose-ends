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


class RunXcodebuildTestLanguageTests(unittest.TestCase):
    """Testsprache (#670): `LOOSEENDS_LANG` wird bei `test` zu -testLanguage/-testRegion."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        stubs = self.root / "stubs"
        stubs.mkdir()
        self.args_file = self.root / "xcodebuild-args"
        xcodebuild = stubs / "xcodebuild"
        xcodebuild.write_text(f'#!/bin/bash\nprintf "%s\\n" "$@" > "{self.args_file}"\nenv > "{self.args_file}.env"\n')
        xcodebuild.chmod(0o755)
        xcbeautify = stubs / "xcbeautify"
        xcbeautify.write_text("#!/bin/bash\ncat >/dev/null\n")
        xcbeautify.chmod(0o755)
        self.base_env = {k: v for k, v in os.environ.items()
                         if k not in ("LOOSEENDS_LANG", "LOOSEENDS_UPDATE_GOLDEN", "LOOSEENDS_UI_LANG")}
        self.base_env["PATH"] = f"{stubs}:/usr/bin:/bin"

    def run_with(self, lang, *args, golden=None, ui_lang=None):
        env = dict(self.base_env)
        if ui_lang is not None:
            env["LOOSEENDS_UI_LANG"] = ui_lang
        if lang is not None:
            env["LOOSEENDS_LANG"] = lang
        if golden is not None:
            env["LOOSEENDS_UPDATE_GOLDEN"] = golden
        script = "\n".join([
            "set -euo pipefail",
            f'PROJECT_DIR="{self.root}"',
            f'SESSION_DERIVED_DATA="{self.root}/DerivedData"',
            run_xcodebuild_source(),
            'run_xcodebuild "$@"',
        ])
        return subprocess.run(["bash", "-c", script, "sim.sh", *args], env=env,
                              capture_output=True, text=True, timeout=30)

    def args_of(self, lang, *args):
        result = self.run_with(lang, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.args_file.read_text().splitlines()

    def test_without_variable_arguments_are_unchanged(self):
        args = self.args_of(None, "test", "-project", "P.xcodeproj")
        self.assertEqual(args[:5], ["test", "-project", "P.xcodeproj", "-collect-test-diagnostics", "never"])
        self.assertNotIn("-testLanguage", args)
        self.assertNotIn("-testRegion", args)

    def test_en_sets_language_and_region(self):
        args = self.args_of("en", "test", "-project", "P.xcodeproj")
        self.assertEqual(args[args.index("-testLanguage") + 1], "en")
        self.assertEqual(args[args.index("-testRegion") + 1], "US")

    def test_de_sets_de_region(self):
        args = self.args_of("de", "test", "-project", "P.xcodeproj")
        self.assertEqual(args[args.index("-testLanguage") + 1], "de")
        self.assertEqual(args[args.index("-testRegion") + 1], "DE")

    def test_unknown_valid_code_sets_language_only(self):
        args = self.args_of("zz", "test", "-project", "P.xcodeproj")
        self.assertEqual(args[args.index("-testLanguage") + 1], "zz")
        self.assertNotIn("-testRegion", args)

    def test_invalid_values_abort_loudly(self):
        for value in ["", "EN", "en-US", "e n", "eng"]:
            with self.subTest(value=value):
                self.args_file.unlink(missing_ok=True)
                result = self.run_with(value, "test", "-project", "P.xcodeproj")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("LOOSEENDS_LANG", result.stderr)
                self.assertIn(f"LOOSEENDS_LANG={value} ", result.stderr)
                self.assertFalse(self.args_file.exists(), "xcodebuild lief trotz ungültiger Sprache")

    def test_update_golden_is_passed_through(self):
        env_file = Path(f"{self.args_file}.env")
        self.assertEqual(self.run_with(None, "test", "-project", "P.xcodeproj", golden="1").returncode, 0)
        self.assertIn("TEST_RUNNER_LOOSEENDS_UPDATE_GOLDEN=1", env_file.read_text().splitlines())
        env_file.unlink()
        self.assertEqual(self.run_with(None, "test", "-project", "P.xcodeproj").returncode, 0)
        self.assertNotIn("TEST_RUNNER_LOOSEENDS_UPDATE_GOLDEN", env_file.read_text())

    def test_ui_lang_is_passed_through(self):
        env_file = Path(f"{self.args_file}.env")
        self.assertEqual(self.run_with(None, "test", "-project", "P.xcodeproj", ui_lang="de").returncode, 0)
        self.assertIn("TEST_RUNNER_LOOSEENDS_UI_LANG=de", env_file.read_text().splitlines())
        env_file.unlink()
        self.assertEqual(self.run_with(None, "test", "-project", "P.xcodeproj").returncode, 0)
        self.assertNotIn("TEST_RUNNER_LOOSEENDS_UI_LANG", env_file.read_text())

    def test_build_action_ignores_variable(self):
        for value in ["en", ""]:
            with self.subTest(value=value):
                baseline = self.args_of(None, "build", "-project", "P.xcodeproj")
                self.assertEqual(self.args_of(value, "build", "-project", "P.xcodeproj"), baseline)
                self.assertNotIn("-testLanguage", baseline)


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

    def test_watcher_ends_when_script_dies(self):
        """F001: stirbt sim.sh per KILL, löst der Wächter nicht mehr aus; der xcodebuild bleibt bewusst als Waise."""
        self.stub(f'echo eins\necho $$ > "{self.root}/pid"\nexec sleep 600')
        script = "\n".join([
            "set -euo pipefail",
            f'PROJECT_DIR="{self.root}"',
            f'SESSION_DERIVED_DATA="{self.derived}"',
            run_xcodebuild_source(),
            "run_xcodebuild build -project P.xcodeproj",
        ])
        out_file, err_file = self.root / "out", self.root / "err"
        with open(out_file, "w") as out, open(err_file, "w") as err:
            proc = subprocess.Popen(["bash", "-c", script, "sim.sh"], env=self.environment,
                                    stdout=out, stderr=err, start_new_session=True)
        self.addCleanup(lambda: os.killpg(proc.pid, signal.SIGKILL) if group_alive(proc.pid) else None)
        pid_file = self.root / "pid"
        end = time.time() + 10
        while not pid_file.exists() and time.time() < end:
            time.sleep(0.05)
        self.assertTrue(pid_file.exists(), "xcodebuild-Stub nicht gestartet")
        proc.kill()
        proc.wait()
        time.sleep(5)          # Frist 2 s + Takt 1 s: ein weiterlaufender Wächter hätte jetzt ausgelöst
        pid = int(pid_file.read_text())
        self.assertTrue(alive(pid), "der Wächter einer toten sim.sh hat den xcodebuild beendet")
        self.assertNotIn("abgebrochen", err_file.read_text(), "der Wächter einer toten sim.sh hat ausgelöst")

    def test_term_ignoring_xcodebuild_is_killed_after_grace(self):
        """F003: ein xcodebuild, der TERM ignoriert, endet 5 s später per KILL."""
        self.stub(f"trap '' TERM\necho eins\necho $$ > \"{self.root}/pid\"\nwhile :; do sleep 1; done")
        t0 = time.time()
        result = self.run_guarded(timeout=25)
        took = time.time() - t0
        self.assertNotEqual(result.returncode, 0)
        pid = int((self.root / "pid").read_text())
        self.assertFalse(alive(pid), "der TERM ignorierende xcodebuild lebt noch")
        self.assertGreaterEqual(took, 7, "KILL kam vor Frist + 5 s Nachfrist")


FAKE_SIMCTL = r'''#!/bin/bash
# simctl-Ersatz: hält AppleLanguages/AppleLocale je Schlüssel in einer Datei, protokolliert jeden Aufruf.
echo "$*" >> "$SIM_LOG"
[ "$1" = spawn ] || exit 0
op="$4" key="$6" file="$SIM_STATE/$6"
case "$op" in
    read) [ -f "$file" ] || exit 1; cat "$file" ;;
    delete) rm "$file" ;;
    write) shift 6
        if [ "$1" = -array ]; then shift; { echo "("; for v in "$@"; do echo "    \"$v\","; done; echo ")"; } > "$file"
        else echo "$2" > "$file"; fi ;;
esac
'''


class StoreSimulatorLanguageTests(unittest.TestCase):
    """Systemsprache des Simulators für die Store-Bilder (#842): nur bei Abweichung umstellen, immer zurück."""

    FUNCTIONS = ["store_sim_read", "store_sim_write", "store_sim_reboot", "store_set_lang", "store_restore_lang"]

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        self.state, self.log = self.root / "state", self.root / "log"
        self.state.mkdir()
        self.log.write_text("")
        simctl = self.root / "simctl"
        simctl.write_text(FAKE_SIMCTL)
        simctl.chmod(0o755)
        self.env = dict(os.environ, SIM_STATE=str(self.state), SIM_LOG=str(self.log))

    def given(self, languages=None, locale=None):
        if languages is not None:
            (self.state / "AppleLanguages").write_text("(\n" + ",\n".join(f'    "{v}"' for v in languages) + "\n)\n")
        if locale is not None:
            (self.state / "AppleLocale").write_text(locale + "\n")

    def run_sim(self, *lines):
        text = (SCRIPTS / "sim.sh").read_text()
        sources = []
        for name in self.FUNCTIONS:
            match = re.search(rf"(?ms)^{name}\(\) \{{.*?^\}}", text)
            self.assertIsNotNone(match, f"{name}() fehlt in scripts/sim.sh")
            sources.append(match.group(0))
        script = "\n".join(["set -eo pipefail", f'SIMCTL="{self.root / "simctl"}"', 'STORE_LANG_RESTORE=""',
                            'info() { :; }', 'warn() { echo "$1" >&2; }', *sources, *lines])
        return subprocess.run(["bash", "-c", script], env=self.env, capture_output=True, text=True, timeout=30)

    def value(self, key):
        path = self.state / key
        return path.read_text() if path.exists() else None

    def test_matching_language_changes_nothing(self):
        self.given(["de-DE"], "de_DE")
        result = self.run_sim('store_set_lang SIM de', 'echo "restore=[$STORE_LANG_RESTORE]"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("restore=[]", result.stdout)
        self.assertNotIn("write", self.log.read_text())
        self.assertNotIn("shutdown", self.log.read_text())

    def test_english_run_switches_reboots_and_restores(self):
        self.given(["de-DE", "en"], "de_DE")
        before = (self.value("AppleLanguages"), self.value("AppleLocale"))
        result = self.run_sim("store_set_lang SIM en", 'cp "$SIM_STATE/AppleLanguages" "$SIM_STATE/during"',
                              "store_restore_lang")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"en"', self.value("during"))
        calls = self.log.read_text().splitlines()
        self.assertEqual(calls.count("shutdown SIM"), 2, "je ein Neustart beim Umstellen und beim Zurücksetzen")
        self.assertIn("bootstatus SIM -b", calls)
        self.assertIn("spawn SIM defaults write -g AppleLocale -string en_US", calls)
        self.assertIn("spawn SIM defaults write -g AppleLanguages -array de-DE en", calls)
        self.assertEqual(self.value("AppleLocale"), before[1])

    def test_unset_values_are_removed_again(self):
        result = self.run_sim("store_set_lang SIM en", "store_restore_lang")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(self.value("AppleLanguages"))
        self.assertIsNone(self.value("AppleLocale"))

    def test_aborted_run_restores_through_exit_trap(self):
        self.given(["de-DE"], "de_DE")
        result = self.run_sim("trap store_restore_lang EXIT", "store_set_lang SIM en", "exit 3")
        self.assertEqual(result.returncode, 3)
        self.assertIn('"de-DE"', self.value("AppleLanguages"))
        self.assertEqual(self.value("AppleLocale"), "de_DE\n")


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
    except (ProcessLookupError, PermissionError):
        return False
    return True


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


if __name__ == "__main__":
    unittest.main()
