"""Tests: das Datenschutz-Manifest folgt dem Konto-Schalter (#625 Schnitt 2).

Aufruf: python3 scripts/test_privacy_manifest.py

Store-Bauten (Schalter `LEAccountEnabled` aus) erheben nichts, ihr Manifest bleibt leer. Bauten mit `konto` an senden
die Apple-Kennung, die Abschrift der offenen Aufgaben und die Kennung der Installation an den Dienst; ihr Manifest
bekommt im CI genau diese drei Typen (`privacy_manifest.py apply`), und die Archivprüfung hält beides fest (`check`).
Das Skript wird als Prozess aufgerufen, weil Ausgang und Meldung der Vertrag mit dem Workflow sind.
"""
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
SCRIPT = SCRIPTS / "privacy_manifest.py"
SOURCE = ROOT / "LooseEnds" / "PrivacyInfo.xcprivacy"
WORKFLOW = ROOT / ".github" / "workflows" / "testflight.yml"

TYPES = {
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeDeviceID",
    "NSPrivacyCollectedDataTypeOtherUserContent",
}
PURPOSE = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
APPLY = "python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy"
CHECK = 'python3 scripts/privacy_manifest.py check'


def entry(kind, linked=True, tracking=False, purposes=(PURPOSE,)):
    item = {
        "NSPrivacyCollectedDataType": kind,
        "NSPrivacyCollectedDataTypeLinked": linked,
        "NSPrivacyCollectedDataTypeTracking": tracking,
    }
    if purposes is not None:
        item["NSPrivacyCollectedDataTypePurposes"] = list(purposes)
    return item


def full():
    return [entry(kind) for kind in sorted(TYPES)]


def run(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)


class ManifestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.copy = self.tmp / "PrivacyInfo.xcprivacy"
        shutil.copyfile(SOURCE, self.copy)

    def load(self, path=None):
        with open(path or self.copy, "rb") as handle:
            return plistlib.load(handle)

    def write(self, types):
        manifest = self.load()
        manifest["NSPrivacyCollectedDataTypes"] = types
        with open(self.copy, "wb") as handle:
            plistlib.dump(manifest, handle)

    def assertRefused(self, result, *words):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        for word in words:
            self.assertIn(word, result.stderr)


class ApplyTests(ManifestCase):
    def test_apply_writes_the_three_types_and_check_true_accepts(self):  # AC-1
        result = run("apply", str(self.copy))
        self.assertEqual(result.returncode, 0, result.stderr)
        types = self.load()["NSPrivacyCollectedDataTypes"]
        self.assertEqual({t["NSPrivacyCollectedDataType"] for t in types}, TYPES)
        self.assertEqual(len(types), 3)
        for item in types:
            self.assertIs(item["NSPrivacyCollectedDataTypeLinked"], True)
            self.assertIs(item["NSPrivacyCollectedDataTypeTracking"], False)
            self.assertEqual(item["NSPrivacyCollectedDataTypePurposes"], [PURPOSE])
        self.assertEqual(run("check", str(self.copy), "--account", "true").returncode, 0)

    def test_apply_twice_changes_nothing_and_keeps_other_keys(self):  # AC-2
        before = self.load()
        run("apply", str(self.copy))
        once = self.load()
        self.assertEqual(run("apply", str(self.copy)).returncode, 0)
        self.assertEqual(self.load(), once)
        for key in before:
            if key != "NSPrivacyCollectedDataTypes":
                self.assertEqual(once[key], before[key], key)
        reasons = once["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"]
        self.assertEqual(reasons, ["CA92.1"])


class CheckTests(ManifestCase):
    def test_source_carries_the_three_types_and_passes_only_with_account(self):  # S5b AC-3, AC-4
        source = self.load(SOURCE)
        sys.path.insert(0, str(SCRIPTS))
        from privacy_manifest import ACCOUNT_TYPES  # die eine Quelle, Reihenfolge wie apply sie schreibt
        self.assertEqual(source.get("NSPrivacyCollectedDataTypes"), ACCOUNT_TYPES)
        self.assertIs(source["NSPrivacyTracking"], False)
        reasons = source["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"]
        self.assertEqual(reasons, ["CA92.1"])
        self.assertEqual(run("check", str(SOURCE), "--account", "true").returncode, 0)
        self.assertRefused(run("check", str(SOURCE), "--account", "false"), "NSPrivacyCollectedDataTypes")
        self.assertEqual(run("apply", str(self.copy)).returncode, 0)  # die Quelle ist schon das Erzeugnis von apply
        self.assertEqual(self.load(), source)

    def test_filled_manifest_fails_without_account(self):  # AC-4
        self.write(full())
        self.assertRefused(run("check", str(self.copy), "--account", "false"), "NSPrivacyCollectedDataTypes")

    def test_foreign_type_is_named(self):  # AC-5
        self.write(full() + [entry("NSPrivacyCollectedDataTypeEmailAddress")])
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "NSPrivacyCollectedDataTypeEmailAddress")

    def test_duplicate_type_is_named(self):  # AC-5
        self.write(full() + [entry("NSPrivacyCollectedDataTypeUserID")])
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "NSPrivacyCollectedDataTypeUserID")

    def test_missing_type_is_named(self):  # AC-5
        self.write([t for t in full() if t["NSPrivacyCollectedDataType"] != "NSPrivacyCollectedDataTypeDeviceID"])
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "NSPrivacyCollectedDataTypeDeviceID")

    def test_tracking_true_is_named(self):  # AC-5
        types = full()
        types[0]["NSPrivacyCollectedDataTypeTracking"] = True
        self.write(types)
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "Tracking")

    def test_missing_purpose_is_named(self):  # AC-5
        types = full()
        del types[1]["NSPrivacyCollectedDataTypePurposes"]
        self.write(types)
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "Purposes")

    def test_unlinked_type_is_refused(self):  # AC-5 (Linked muss true sein)
        types = full()
        types[2]["NSPrivacyCollectedDataTypeLinked"] = False
        self.write(types)
        self.assertRefused(run("check", str(self.copy), "--account", "true"), "Linked")


class CallErrorTests(ManifestCase):
    def test_unreadable_file(self):  # AC-6
        self.copy.write_text("kein plist")
        self.assertRefused(run("check", str(self.copy), "--account", "false"), "PrivacyInfo.xcprivacy")
        self.assertRefused(run("apply", str(self.copy)), "PrivacyInfo.xcprivacy")

    def test_missing_path(self):  # AC-6
        missing = str(self.tmp / "fehlt.xcprivacy")
        self.assertRefused(run("check", missing, "--account", "false"), "fehlt.xcprivacy")
        self.assertRefused(run("apply", missing), "fehlt.xcprivacy")

    def test_invalid_account_value(self):  # AC-6
        self.assertRefused(run("check", str(self.copy), "--account", "ja"), "--account")


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text()
        cls.flow = yaml.safe_load(cls.text)  # AC-11: gültiges YAML

    def steps(self, job):
        return self.flow["jobs"][job]["steps"]

    def step(self, job, name):
        found = [s for s in self.steps(job) if s.get("name") == name]
        self.assertEqual(len(found), 1, f"{job}: Schritt '{name}' fehlt oder doppelt")
        return found[0]

    def test_apply_not_in_workflow(self):  # #625 S5c AC-2: der Schalter steht an der Quelle, kein Schritt schreibt ihn
        for job in ("upload", "upload-mac"):
            names = [s.get("name") for s in self.steps(job)]
            self.assertNotIn("Set the account switch", names, job)
            self.assertIn("Set the APNs environment", names, job)
        self.assertNotIn("privacy_manifest.py apply", self.text)
        self.assertNotIn(APPLY, self.text)
        self.assertNotIn("plutil -replace LEAccountEnabled", self.text)

    def test_archive_checks_call_check_with_account_true(self):  # #625 S5c AC-4
        ios = [s["run"] for s in self.steps("upload") if CHECK in s.get("run", "")]
        mac = [s["run"] for s in self.steps("upload-mac") if CHECK in s.get("run", "")]
        self.assertEqual(len(ios), 1)
        self.assertEqual(len(mac), 1)
        self.assertIn('"$APP/Contents/Resources/PrivacyInfo.xcprivacy"', mac[0])
        for body in (ios[0], mac[0]):
            line = next(l for l in body.splitlines() if CHECK in l)
            self.assertIn("--account true", line)
            self.assertIn("fail=1", line)
            self.assertNotIn("ACCOUNT_BUILD", body)
            self.assertNotIn("--account false", body)
            self.assertNotIn('--account "$', body)

    def test_ios_check_targets_only_the_app_bundle(self):  # AC-10
        body = next(s["run"] for s in self.steps("upload") if CHECK in s.get("run", ""))
        line = next(l for l in body.splitlines() if CHECK in l)
        self.assertNotIn("com.henning.looseends.", line)
        self.assertIn("$app_info", body)
        self.assertEqual(body.count(CHECK), 1)

    def test_account_switch_blocks_unchanged(self):  # AC-11
        blocks = self.text.split("# account-switch-check:begin")[1:]
        self.assertEqual(len(blocks), 2)
        for block in blocks:
            self.assertNotIn("privacy_manifest", block.split("# account-switch-check:end")[0])


if __name__ == "__main__":
    unittest.main()
