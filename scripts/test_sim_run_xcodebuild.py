"""Tests für `run_xcodebuild` in sim.sh: Testläufe ohne Simulator-Diagnose (#298).

`xcodebuild test` sammelt nach dem Ergebnis per `simctl diagnose` Diagnosen und wartet darauf, im
Lauf zu #274 bis zu 19 Minuten. `-collect-test-diagnostics never` schaltet das ab, nur für `test`.

Aufruf: python3 -m unittest scripts/test_sim_run_xcodebuild.py
"""
import os
import re
import shutil
import subprocess
import tempfile
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


if __name__ == "__main__":
    unittest.main()
