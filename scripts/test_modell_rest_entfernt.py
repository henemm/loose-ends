"""Tests: der tote Modellrest ist aus App und Tests entfernt (#982 Schnitt 3a, ADR-22), und der Modelladapter
steckt in keinem Release-Bau mehr (#982 Schnitt 3b).

Aufruf: python3 scripts/test_modell_rest_entfernt.py [Wurzel]

Seit Schnitt 1 ruft das Produkt das Modell nicht mehr auf. Dieser Test prüft, dass die nur dafür gebauten Helfer
(Zeitlimit, Fehlerklassen, der Schreiber für Modellentwürfe, die Beispiele, die Titelprüfungen für Modelltitel, der
Test-Stub) und zwei unbenutzte Texte weg sind, während Messcode, Labor-App und die Texte für alte KI-Werte bleiben.
Ohne Argument gilt das Repo als Wurzel, mit Argument ein anderer Stand (RED-Nachweis gegen einen älteren Commit).
"""
import json
import re
import sys
import unittest

import yaml
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REMOVED_FILES = ("Shared/Enrichment/ModelDeadline.swift", "Shared/Enrichment/ModelFailure.swift")
CODE_FOLDERS = ("LooseEnds", "Shared", "LooseEndsTests", "LooseEndsLab", "Measurement")
APP_FOLDERS = ("LooseEnds", "Shared")
REMOVED_WORDS = (
    "ModelDeadline", "ModelFailure", "StubEnricher", "EnrichmentWriter.apply(", "examples(in:",
    "confidenceThreshold", "exampleLimit",
)
REMOVED_TITLE_CHECKS = re.compile(r"\b(isFromNote|addsDate|borrows)\b")
KEPT_WRITER_PARTS = ("enum Mode", "static func mayWrite", "static func userHasTouched", "static func encode")
REMOVED_KEYS = (
    "That happens by itself once Apple Intelligence is ready.",
    "Apple Intelligence did not run, only the rules.",
)
KEPT_KEYS = ("Estimated by Apple Intelligence", "The project was a guess of the model, not from your words.")
KEPT_FILES = (
    "Shared/Enrichment/FoundationModelsEnricher.swift", "Shared/Enrichment/EnrichmentDraft.swift",
    "LooseEndsLab/MeasurementRunner.swift", "LooseEndsTests/RealModelTests.swift",
)


ADAPTER = "Shared/Enrichment/FoundationModelsEnricher.swift"
DRAFT = "Shared/Enrichment/EnrichmentDraft.swift"
MOVED_TYPES = ("struct EnrichmentInput", "struct EnrichmentExample", "protocol TaskEnricher", "enum EnrichmentParsing")
KEPT_DRAFT_TYPES = ("struct EnrichmentDraft", "struct Guess")
MODEL_GUARD = "#if canImport(FoundationModels)"
EXCLUDE_ENTRY = "Enrichment/FoundationModelsEnricher.swift"
EXCLUDED_TARGETS = ("LooseEndsWidgets", "LooseEndsShare", "LooseEndsWatch")
STALE_COMMENT = "`Measurement/MeasurementRun.swift` compiles into three targets"
ARCHIVE_JOBS = ("upload", "upload-mac")
ARCHIVE_CHECK_PARTS = ("nm", "otool -L", "FoundationModelsEnricher", "FoundationModels", "::error::", "CFBundleExecutable")


def swift_files(folders):
    for folder in folders:
        yield from sorted((ROOT / folder).rglob("*.swift"))


class ModellRestEntferntTests(unittest.TestCase):
    def test_deadline_and_failure_files_are_gone(self):
        left = [name for name in REMOVED_FILES if (ROOT / name).exists()]
        self.assertEqual(left, [], "Modell-Hilfsdateien gibt es noch")

    def test_no_code_names_the_removed_helpers(self):
        hits = []
        for path in swift_files(CODE_FOLDERS):
            text = path.read_text(encoding="utf-8")
            hits += [f"{path.relative_to(ROOT)}: {word}" for word in REMOVED_WORDS if word in text]
        self.assertEqual(hits, [], "Modellrest noch im Code")

    def test_app_code_has_no_model_title_checks(self):
        hits = [str(path.relative_to(ROOT)) for path in swift_files(APP_FOLDERS)
                if REMOVED_TITLE_CHECKS.search(path.read_text(encoding="utf-8"))]
        self.assertEqual(hits, [], "Titelprüfungen für Modelltitel noch im App-Code")

    def test_writer_keeps_what_the_rules_use(self):
        text = (ROOT / "Shared/Enrichment/EnrichmentWriter.swift").read_text(encoding="utf-8")
        missing = [part for part in KEPT_WRITER_PARTS if part not in text]
        self.assertEqual(missing, [], "Regelteile des Schreibers fehlen")

    def test_catalog_drops_dead_keys_and_keeps_old_value_labels(self):
        keys = json.loads((ROOT / "LooseEnds/Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        self.assertEqual([key for key in REMOVED_KEYS if key in keys], [], "tote Schlüssel stehen noch im Katalog")
        self.assertEqual([key for key in KEPT_KEYS if key not in keys], [], "Texte für alte KI-Werte fehlen")

    def test_measurement_code_and_lab_stay(self):
        missing = [name for name in KEPT_FILES if not (ROOT / name).exists()]
        self.assertEqual(missing, [], "Messcode oder Labor-App fehlt")



def project():
    return yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))


def shared_excludes(target):
    """The excludes of the target's `Shared` source entry (plain `- Shared` has none)."""
    for source in target.get("sources", []):
        if source == "Shared":
            return []
        if isinstance(source, dict) and source.get("path") == "Shared":
            return source.get("excludes", [])
    return None


class AdapterNichtImReleaseTests(unittest.TestCase):
    """#982 S3b: der Adapter bleibt nur im Debug-Testhost und in der Labor-App."""

    def test_moved_types_live_beside_the_adapter_outside_the_guard(self):
        draft = (ROOT / DRAFT).read_text(encoding="utf-8")
        adapter = (ROOT / ADAPTER).read_text(encoding="utf-8")
        self.assertEqual([t for t in MOVED_TYPES if t in draft], [], "Modelltypen stehen noch in EnrichmentDraft.swift")
        self.assertEqual([t for t in KEPT_DRAFT_TYPES if t not in draft], [], "EnrichmentDraft oder Guess fehlt")
        guard = adapter.find(MODEL_GUARD)
        self.assertNotEqual(guard, -1, "Adapter ohne #if canImport(FoundationModels)")
        outside = [t for t in MOVED_TYPES if not 0 <= adapter.find(t) < guard]
        self.assertEqual(outside, [], "Modelltypen fehlen im Adapter vor dem #if")
        self.assertLess(adapter.find("import Foundation\n"), guard, "import Foundation steht nicht vor dem #if")

    def test_extensions_and_watch_exclude_the_adapter(self):
        targets = project()["targets"]
        missing = [name for name in EXCLUDED_TARGETS if EXCLUDE_ENTRY not in (shared_excludes(targets[name]) or [])]
        self.assertEqual(missing, [], "Targets ohne Ausschluss des Adapters")
        for name, kept in (("LooseEndsWidgets", "Intents/CaptureTextIntent.swift"),
                           ("LooseEndsShare", "Intents/NextUpWidgetIntents.swift")):
            self.assertIn(kept, shared_excludes(targets[name]), f"bestehender Ausschluss in {name} verloren")

    def test_app_excludes_the_adapter_in_release_only(self):
        target = project()["targets"]["LooseEnds"]
        settings = target.get("settings", {})
        release = settings.get("configs", {}).get("Release", {})
        self.assertIn("FoundationModelsEnricher.swift", str(release.get("EXCLUDED_SOURCE_FILE_NAMES", "")),
                      "Release der App schließt den Adapter nicht aus")
        self.assertNotIn("EXCLUDED_SOURCE_FILE_NAMES", settings.get("base", {}), "Ausschluss gilt auch für Debug")
        self.assertNotIn("Debug", {k for k, v in settings.get("configs", {}).items()
                                   if "EXCLUDED_SOURCE_FILE_NAMES" in (v or {})}, "Ausschluss gilt auch für Debug")

    def test_lab_keeps_the_adapter(self):
        sources = project()["targets"]["LooseEndsLab"]["sources"]
        paths = [s.get("path") if isinstance(s, dict) else s for s in sources]
        self.assertIn(ADAPTER, paths, "Labor-App verliert den Adapter")

    def test_ci_drops_the_model_diagnosis(self):
        ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertFalse("Diagnose model availability" in ci, "toter CI-Schritt zur Modellverfügbarkeit steht noch")

    def test_archive_jobs_refuse_the_adapter(self):
        jobs = yaml.safe_load((ROOT / ".github/workflows/testflight.yml").read_text(encoding="utf-8"))["jobs"]
        for job in ARCHIVE_JOBS:
            runs = [step.get("run", "") for step in jobs[job]["steps"]]
            checks = [run for run in runs if "FoundationModelsEnricher" in run]
            self.assertTrue(checks, f"{job}: keine Archivprüfung auf den Modelladapter")
            missing = [part for part in ARCHIVE_CHECK_PARTS if not any(part in run for run in checks)]
            self.assertEqual(missing, [], f"{job}: Archivprüfung unvollständig")

    def test_stale_measurement_comment_is_gone(self):
        draft = (ROOT / DRAFT).read_text(encoding="utf-8")
        self.assertFalse(STALE_COMMENT in draft, "Kommentar verweist auf eine Stelle, die es nicht gibt")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        ROOT = Path(sys.argv.pop(1)).resolve()
    unittest.main()
