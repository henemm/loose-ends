"""Tests: Der CI-Klicktest bekommt die Sandbox der echten Mac-App (#544).

Aufruf: python3 scripts/test_mac_ci_entitlements.py
"""
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import mac_ci_entitlements as subject  # noqa: E402


class SandboxEntitlements(unittest.TestCase):
    def project(self):
        return yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))

    def test_keeps_the_sandbox_and_what_it_allows(self):
        kept = subject.sandbox_entitlements(self.project())
        self.assertIs(kept["com.apple.security.app-sandbox"], True)
        app = self.project()["targets"]["LooseEnds"]["entitlements"]["properties"]
        for key, value in app.items():
            if key.startswith("com.apple.security.") and key != "com.apple.security.application-groups":
                self.assertEqual(kept.get(key), value, key)

    def test_drops_what_needs_a_profile(self):
        kept = subject.sandbox_entitlements(self.project())
        for key in kept:
            self.assertFalse(key.startswith("com.apple.developer."), key)
        self.assertNotIn("aps-environment", kept)
        self.assertNotIn("com.apple.security.application-groups", kept)

    def test_writes_a_plist_with_exactly_those_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "sandbox.plist"
            result = subprocess.run([sys.executable, str(ROOT / "scripts" / "mac_ci_entitlements.py"), str(out)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(plistlib.loads(out.read_bytes()), subject.sandbox_entitlements(self.project()))

    def test_refuses_a_project_without_sandbox(self):
        project = self.project()
        project["targets"]["LooseEnds"]["entitlements"]["properties"].pop("com.apple.security.app-sandbox")
        self.assertNotIn("com.apple.security.app-sandbox", subject.sandbox_entitlements(project))


class ArchiveCheck(unittest.TestCase):
    """The TestFlight run checks the signed Mac archive for every sandbox key the app declares (#544):
    files.user-selected was missing in build 89 and nothing noticed."""

    def test_testflight_checks_every_sandbox_key_of_the_app(self):
        project = yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))
        workflow = (ROOT / ".github" / "workflows" / "testflight.yml").read_text(encoding="utf-8")
        loop = next(line for line in workflow.splitlines() if "for key in com.apple.security.app-sandbox" in line)
        checked = set(loop.split(" in ", 1)[1].rstrip("; do").split())
        for key in subject.sandbox_entitlements(project):
            self.assertIn(key, checked, f"{key} fehlt in der Archivprüfung (macOS) von testflight.yml")


if __name__ == "__main__":
    unittest.main()
