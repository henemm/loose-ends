"""Tests: der tote Modellrest ist aus App und Tests entfernt (#982 Schnitt 3a, ADR-22).

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


if __name__ == "__main__":
    if len(sys.argv) > 1:
        ROOT = Path(sys.argv.pop(1)).resolve()
    unittest.main()
