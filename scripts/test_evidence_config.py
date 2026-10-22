"""Tests für das Einschalten des Simulator-Beleg-Gates in Loose Ends (#145, Schnitt 2).

AC-23: `openspec.yaml` trägt `evidence_checks.phase8_complete` in der Form der Spec
(docs/specs/tooling/feat-145-s2-gate.md). AC-21: Die Dateimenge, die `sim_proof.py` in den Beleg
schreibt, ist eine Obermenge der Menge, die das Plugin-Gate mit der Loose-Ends-Konfiguration verlangt.

Aufruf: python3 -m unittest scripts/test_evidence_config.py
"""
import importlib.util
import json
import sys
import unittest
from pathlib import Path

import yaml

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))
import sim_proof  # noqa: E402

# Musterpfade aus AC-21: Code in allen Quellordnern, dazu Doku, Skripte und Daten.
SAMPLE_PATHS = [
    "LooseEnds/Views/InboxDrawerView.swift",
    "LooseEnds/Mac/MenuBarCapture.swift",
    "LooseEnds/App/LaunchTimings.swift",
    "Shared/Models/RepeatRule.swift",
    "Shared/Services/CaptureService.swift",
    "LooseEndsTests/RepeatRuleTests.swift",
    "LooseEndsUITests/CaptureSmokeTests.swift",
    "Measurement/LeaveOneOut.swift",
    "LooseEndsWatch/WatchCapture.swift",
    "docs/reference/abnahme-und-arbeitsweise.md",
    "docs/artifacts/feat-145-s2-gate/simulator-run.txt",
    "scripts/sim_proof.py",
    "README.md",
    "cloudkit/schema.json",
    "project.yml",
]


def load_project_config():
    with open(ROOT / "openspec.yaml", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def plugin_hook_utils():
    """hook_utils des lokal installierten Plugins, sonst None (CI hat kein Plugin)."""
    registry = Path.home() / ".claude/plugins/installed_plugins.json"
    if not registry.is_file():
        return None
    plugins = json.loads(registry.read_text(encoding="utf-8")).get("plugins", {})
    for key, entries in plugins.items():
        if not key.startswith("agent-os-openspec@") or not entries:
            continue
        entry = next((e for e in entries if e.get("scope") == "user"), entries[0])
        path = Path(entry.get("installPath", "")) / "core/hooks/hook_utils.py"
        if path.is_file():
            sys.path.insert(0, str(path.parent))
            spec = importlib.util.spec_from_file_location("plugin_hook_utils", path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module
    return None


class EvidenceConfigTests(unittest.TestCase):
    """AC-23: Form und Inhalt des Abschnitts `evidence_checks`."""

    def setUp(self):
        self.config = load_project_config()

    def checks(self):
        section = self.config.get("evidence_checks")
        self.assertIsInstance(section, dict, "openspec.yaml: Abschnitt evidence_checks fehlt")
        entries = section.get("phase8_complete")
        self.assertIsInstance(entries, list, "evidence_checks.phase8_complete ist keine Liste")
        self.assertEqual(len(entries), 1, "genau ein Belegtyp für phase8_complete erwartet")
        return entries[0]

    def test_phase8_requires_xcresult_proof(self):
        self.assertEqual(self.checks().get("type"), "xcresult_proof")

    def test_artifact_is_simulator_run(self):
        self.assertEqual(self.checks().get("artifact"), "simulator-run.txt")

    def test_only_mac_folder_is_exempt(self):
        self.assertEqual(self.checks().get("exempt_paths"), ["LooseEnds/Mac/"])

    def test_no_other_phase_is_gated(self):
        section = self.config.get("evidence_checks") or {}
        self.assertEqual(set(section), {"phase8_complete"},
                         "der Beleg sperrt nur „fertig“, keine Zwischenphase")


class ProducerCoversGateTests(unittest.TestCase):
    """AC-21: Erzeuger-Menge ⊇ Gate-Menge mit der Loose-Ends-Konfiguration."""

    def setUp(self):
        self.hook_utils = plugin_hook_utils()
        if self.hook_utils is None:
            self.skipTest("agent-os-openspec ist hier nicht installiert (CI): Driftprüfung nur lokal")
        self.config = load_project_config()

    def gate_paths(self):
        exempt = []
        for entry in (self.config.get("evidence_checks") or {}).get("phase8_complete", []):
            exempt += entry.get("exempt_paths", [])
        return {p for p in SAMPLE_PATHS
                if self.hook_utils.is_gated_code_path(p, self.config)
                and not any(p.startswith(e) for e in exempt)}

    def test_gate_set_is_not_empty(self):
        self.assertIn("LooseEnds/Views/InboxDrawerView.swift", self.gate_paths())

    def test_producer_covers_every_gate_path(self):
        producer = {p for p in SAMPLE_PATHS if sim_proof.is_gated_code_path(p)}
        missing = sorted(self.gate_paths() - producer)
        self.assertEqual(missing, [], f"Gate verlangt, Beleg erfasst nicht: {missing}")

    def test_mac_folder_is_exempt_from_gate(self):
        self.assertNotIn("LooseEnds/Mac/MenuBarCapture.swift", self.gate_paths())


if __name__ == "__main__":
    unittest.main()
