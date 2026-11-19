"""Tests für die Info-Marke LEApsEnvironment (#795 Schnitt 5c-2b) und den Push-Schlüssel des Macs (S5c-2b2).

Aufruf: python3 scripts/test_aps_environment.py
Quelle und Abbild tragen `sandbox`; nur der TestFlight-Lauf setzt `production` und prüft es im Archiv.
Ob Apple den Token in dieser Umgebung annimmt, zeigt erst der echte Lauf mit S5c-2a.
"""
import hashlib
import os
import plistlib
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.yml"
APP_INFO = ROOT / "LooseEnds" / "Info.plist"
APP_ENTITLEMENTS = ROOT / "LooseEnds" / "LooseEnds.entitlements"
MAC_PUSH = "com.apple.developer.aps-environment"
WORKFLOW = ROOT / ".github" / "workflows" / "testflight.yml"
KEY = "LEApsEnvironment"
SET_LINE = "plutil -replace LEApsEnvironment -string production"
STEP = "Set the APNs environment"
APS_BEGIN, APS_END = "# aps-environment-check:begin", "# aps-environment-check:end"
ACCOUNT_BEGIN, ACCOUNT_END = "# account-switch-check:begin", "# account-switch-check:end"
# SHA-256 der beiden account-switch-check-Blöcke vor diesem Schnitt (#615 S4c-2a); beide sind gleich
ACCOUNT_BLOCK_SHA = "61a92665763135516a59c8583f71c6577e93aa8d98e591e171af777a6d8427d9"
JOBS = (("upload", "Archive", "Verify the archive is built against the iOS 27 SDK"),
        ("upload-mac", "Archive (macOS)", "Verify the macOS archive"))


def app_info_properties():
    project = yaml.safe_load(PROJECT.read_text(encoding="utf-8"))
    found = [t for t in project["targets"].values() if (t.get("info") or {}).get("path") == "LooseEnds/Info.plist"]
    assert len(found) == 1, "kein eindeutiges App-Ziel mit info.path LooseEnds/Info.plist"
    return found[0]["info"].get("properties", {})


class SourceTests(unittest.TestCase):
    # AC-1
    def test_source_and_image_default_to_sandbox(self):
        self.assertEqual(app_info_properties().get(KEY), "sandbox")
        info = plistlib.loads(APP_INFO.read_bytes())
        self.assertEqual(info.get(KEY), "sandbox")


class WorkflowBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text(encoding="utf-8")
        cls.flow = yaml.safe_load(cls.text)

    def assertIn(self, member, container, msg=None):  # Schrittblöcke sind lang: nur Fundstück und Ort melden
        if member not in container:
            self.fail(f"{member!r} fehlt{f' ({msg})' if msg else ''}")

    def steps(self, job):
        return self.flow["jobs"][job]["steps"]

    def step(self, job, name):
        found = [s for s in self.steps(job) if s.get("name") == name]
        self.assertEqual(len(found), 1, f"{job}: Schritt '{name}' fehlt oder doppelt")
        return found[0]

    def outside_account_blocks(self, body):
        return re.sub(re.escape(ACCOUNT_BEGIN) + r".*?" + re.escape(ACCOUNT_END), "", body, flags=re.S)


class WorkflowTests(WorkflowBase):

    # AC-3
    def test_step_is_unconditional_in_both_jobs(self):
        for job, archive, _ in JOBS:
            step = self.step(job, STEP)
            self.assertNotIn("if", step, job)
            self.assertIn(SET_LINE, step["run"], job)
            names = [s.get("name") for s in self.steps(job)]
            self.assertLess(names.index("Generate project"), names.index(STEP), job)
            self.assertLess(names.index(STEP), names.index(archive), job)
        self.assertEqual(self.text.count(SET_LINE), 2)

    # AC-4
    def test_ios_verify_checks_mark_and_entitlement(self):
        body = self.outside_account_blocks(self.step("upload", JOBS[0][2])["run"])
        for needle in (APS_BEGIN, APS_END, KEY, "plutil -type", "production"):
            self.assertIn(needle, body)
        self.assertIn('aps_environment "$app_info"', body)
        self.assertIn("entitled com.henning.looseends aps-environment", body)

    # AC-5
    def test_mac_verify_checks_mark(self):
        body = self.outside_account_blocks(self.step("upload-mac", JOBS[1][2])["run"])
        for needle in (APS_BEGIN, APS_END, KEY, "plutil -type", "production"):
            self.assertIn(needle, body)
        self.assertIn('aps_environment "$P"', body)

    # AC-6: der Prüfausschnitt selbst, gegen Beispiel-Plists ausgeführt
    def test_verify_snippet_accepts_only_production_string(self):
        snippets = re.findall(re.escape(APS_BEGIN) + r"\n(.*?)\n\s*" + re.escape(APS_END), self.text, re.S)
        self.assertEqual(len(snippets), 2, "Prüfausschnitt fehlt in der iOS- oder Mac-Prüfung")
        cases = {"string production": ("<string>production</string>", 0),
                 "string sandbox": ("<string>sandbox</string>", 1),
                 "fehlt": ("", 1),
                 "bool true": ("<true/>", 1)}
        with tempfile.TemporaryDirectory() as folder:
            for index, snippet in enumerate(snippets):
                results, expected = {}, {}
                for case, (value, want) in cases.items():
                    plist = Path(folder) / f"{index}-{case.replace(' ', '-')}.plist"
                    entry = f"<key>{KEY}</key>{value}" if value else ""
                    plist.write_text('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
                                     f"<key>CFBundleIdentifier</key><string>x</string>{entry}</dict></plist>\n")
                    script = f'row() {{ :; }}\nfail=0\n{snippet}\naps_environment "$1"\n[ "$fail" = 0 ]\n'
                    run = subprocess.run(["bash", "-c", script, "check", str(plist)], capture_output=True,
                                         text=True, env=dict(os.environ))
                    results[case], expected[case] = (0 if run.returncode == 0 else 1), want
                self.assertEqual(results, expected, f"Prüfausschnitt {index}")

    # AC-7
    def test_account_switch_blocks_untouched(self):
        blocks = re.findall(re.escape(ACCOUNT_BEGIN) + r"\n(.*?)" + re.escape(ACCOUNT_END), self.text, re.S)
        self.assertEqual(len(blocks), 2)
        for block in blocks:
            self.assertEqual(hashlib.sha256(block.encode()).hexdigest(), ACCOUNT_BLOCK_SHA)
            self.assertNotIn(KEY, block)
        for job, _, _ in JOBS:
            self.assertEqual(self.step(job, "Set the account switch")["if"], "env.ACCOUNT_BUILD == 'true'")
        self.assertEqual(self.text.count("plutil -replace LEAccountEnabled"), 2)


def app_entitlement_properties():
    project = yaml.safe_load(PROJECT.read_text(encoding="utf-8"))
    found = [t for t in project["targets"].values()
             if (t.get("entitlements") or {}).get("path") == "LooseEnds/LooseEnds.entitlements"]
    assert len(found) == 1, "kein eindeutiges App-Ziel mit entitlements.path LooseEnds/LooseEnds.entitlements"
    return found[0]["entitlements"].get("properties", {})


class EntitlementTests(WorkflowBase):
    """S5c-2b2: macOS braucht com.apple.developer.aps-environment, der iOS-Schlüssel fällt dort still weg."""

    # AC-1
    def test_source_carries_mac_push_key(self):
        properties = app_entitlement_properties()
        self.assertEqual(properties.get(MAC_PUSH), "development")
        self.assertEqual(properties.get("aps-environment"), "development")

    # AC-2
    def test_image_carries_mac_push_key(self):
        image = plistlib.loads(APP_ENTITLEMENTS.read_bytes())
        self.assertEqual(image.get(MAC_PUSH), "development")
        self.assertEqual(image.get("aps-environment"), "development")

    # AC-3: nur Vorhandensein, vor den Konto-Blöcken, Fehlen setzt fail=1
    def test_mac_verify_requires_push_key(self):
        body = self.step("upload-mac", JOBS[1][2])["run"]
        start = body.index("ents=$(codesign")
        loop = re.search(r"for key in ([^;]+); do\n(.*?)\n\s*done", body[start:], re.S)
        self.assertIsNotNone(loop)
        self.assertIn(MAC_PUSH, loop.group(1).split())
        self.assertLess(start + loop.start(), body.index(ACCOUNT_BEGIN))
        self.assertIn('grep -qF "<key>$key</key>"', loop.group(2))
        self.assertIn("fail=1", loop.group(2))
        self.assertEqual(self.outside_account_blocks(body).count(MAC_PUSH), 1, "Mac-Schlüssel nur in der Schleife")

    # AC-4
    def test_ios_verify_keeps_aps_environment(self):
        body = self.step("upload", JOBS[0][2])["run"]
        self.assertIn("entitled com.henning.looseends aps-environment", body)
        self.assertNotIn(MAC_PUSH, body)


if __name__ == "__main__":
    unittest.main()
