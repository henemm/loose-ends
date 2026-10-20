"""Tests: project.yml und die eingecheckten Info.plist-Dateien sagen dasselbe (#499).

Aufruf: python3 scripts/test_info_plist_sync.py

XcodeGen schreibt jede Info.plist bei `generate` aus `info.properties` der project.yml neu; die Datei im Repo ist
nur ein Abbild. Läuft sie auseinander (2026-10-16: Kameratext, Hintergrundmodus `fetch` und die Kennung des
Hintergrundabgleichs fehlten im Abbild), hinterlässt jeder `generate` einen Diff, der nicht zum Schnitt gehört.
Wie `test_entitlements_sync.py` läuft der Vergleich ohne Xcode, ganz vorn in der CI; der Schritt „Generate leaves
the tree clean“ in ci.yml prüft dasselbe noch einmal mit dem echten XcodeGen.
"""
import plistlib
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

# Was XcodeGen jeder Info.plist von sich aus hinzufügt; alles andere muss aus project.yml kommen.
XCODEGEN_DEFAULTS = {
    "CFBundleDevelopmentRegion", "CFBundleExecutable", "CFBundleIdentifier", "CFBundleInfoDictionaryVersion",
    "CFBundleName", "CFBundlePackageType", "CFBundleShortVersionString", "CFBundleVersion",
}


def declared(project):
    """Je Ziel mit eigener Info.plist: (Pfad der Datei, Schlüssel aus project.yml)."""
    result = {}
    for name, target in project["targets"].items():
        info = target.get("info")
        if info:
            result[name] = (info["path"], info.get("properties", {}))
    return result


class InfoPlistSyncTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(ROOT / "project.yml", encoding="utf-8") as handle:
            cls.targets = declared(yaml.safe_load(handle))

    def test_every_target_with_info_has_a_checked_in_plist(self):
        self.assertIn("LooseEnds", self.targets)
        for name, (path, _) in self.targets.items():
            with self.subTest(target=name):
                self.assertTrue((ROOT / path).is_file(), f"{path} fehlt")

    def test_plist_carries_every_property_of_project_yml(self):
        for name, (path, properties) in self.targets.items():
            with open(ROOT / path, "rb") as handle:
                plist = plistlib.load(handle)
            for key, value in properties.items():
                with self.subTest(target=name, key=key):
                    self.assertIn(key, plist, f"{path}: {key} fehlt; `./scripts/sim.sh generate` schreibt ihn")
                    self.assertEqual(plist[key], value, f"{path}: {key} weicht von project.yml ab")

    def test_plist_has_nothing_beyond_project_yml_and_xcodegen_defaults(self):
        for name, (path, properties) in self.targets.items():
            with open(ROOT / path, "rb") as handle:
                plist = plistlib.load(handle)
            extra = set(plist) - set(properties) - XCODEGEN_DEFAULTS
            with self.subTest(target=name):
                self.assertEqual(extra, set(), f"{path}: nur in der Datei, `generate` würde sie verwerfen: {sorted(extra)}")

    def test_plist_is_what_xcodegen_writes(self):
        """Byte für Byte: XcodeGen serialisiert sortiert, so wie plistlib; eine Handänderung fällt hier auf."""
        for name, (path, properties) in self.targets.items():
            with open(ROOT / path, "rb") as handle:
                raw = handle.read()
            merged = dict(plistlib.loads(raw))
            merged.update(properties)
            with self.subTest(target=name):
                self.assertEqual(raw, plistlib.dumps(merged, sort_keys=True), f"{path} ist nicht, was `generate` schreibt")


if __name__ == "__main__":
    unittest.main()
