"""Tests: project.yml und die eingecheckten .entitlements-Dateien sagen dasselbe (#311).

Aufruf: python3 scripts/test_entitlements_sync.py

XcodeGen schreibt jede .entitlements-Datei bei `generate` aus `entitlements.properties` der project.yml neu.
Steht ein Schlüssel nur in der Datei, verlieren ihn der TestFlight-Bau und jeder Bau nach `generate` still
(so fehlte `com.apple.developer.ubiquity-kvstore-identifier`, und der Abgleich der Mitteilungs-Uhrzeit
zwischen den Geräten griff nicht). Der Vergleich läuft ohne Xcode, ganz vorn in der CI.
"""
import plistlib
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
KVSTORE = "com.apple.developer.ubiquity-kvstore-identifier"


def declared(project):
    """Je Ziel mit eigener Berechtigungsdatei: (Pfad der Datei, Schlüssel aus project.yml)."""
    result = {}
    for name, target in project["targets"].items():
        entitlements = target.get("entitlements")
        if entitlements:
            result[name] = (entitlements["path"], entitlements.get("properties", {}))
    return result


def same(a, b):
    """Typgenau gleich: in Python ist 1 == True, eine Datei mit <integer>1</integer> ist aber nicht `true`."""
    if type(a) is not type(b):
        return False
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


def differences(want, have):
    """Beschreibt jede Abweichung zwischen project.yml (want) und Datei (have), je Schlüssel."""
    problems = []
    for key in sorted(set(want) | set(have)):
        if key not in have:
            problems.append(f"{key}: nur in project.yml, fehlt in der Datei")
        elif key not in want:
            problems.append(f"{key}: nur in der Datei, fehlt in project.yml (wird bei generate gelöscht)")
        elif not same(want[key], have[key]):
            problems.append(f"{key}: project.yml {want[key]!r}, Datei {have[key]!r}")
    return problems


def load_project():
    return yaml.safe_load((ROOT / "project.yml").read_text())


class EntitlementsSyncTests(unittest.TestCase):
    def test_every_target_matches_its_committed_entitlements(self):
        problems = []
        for name, (path, want) in declared(load_project()).items():
            have = plistlib.loads((ROOT / path).read_bytes())
            problems += [f"{name} ({path}) {line}" for line in differences(want, have)]
        self.assertEqual([], problems, "project.yml und eingecheckte Berechtigungen weichen ab:\n" + "\n".join(problems))

    def test_mismatch_is_reported_per_key(self):
        have = {"a": True, "b": "alt", "nur.datei": 1}
        want = {"a": True, "b": "neu", "nur.yml": 2}
        report = "\n".join(differences(want, have))
        self.assertIn("nur.datei: nur in der Datei", report)
        self.assertIn("nur.yml: nur in project.yml", report)
        self.assertIn("b: project.yml 'neu', Datei 'alt'", report)
        self.assertNotIn("a:", report)

    def test_integer_one_is_not_true(self):
        self.assertEqual(["k: project.yml True, Datei 1"], differences({"k": True}, {"k": 1}))
        self.assertEqual(["k: project.yml [True], Datei [1]"], differences({"k": [True]}, {"k": [1]}))

    def test_kvstore_key_is_declared_for_the_app(self):
        _, properties = declared(load_project())["LooseEnds"]
        self.assertEqual("$(TeamIdentifierPrefix)$(CFBundleIdentifier)", properties.get(KVSTORE))


if __name__ == "__main__":
    unittest.main()
