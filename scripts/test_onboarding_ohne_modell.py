"""Tests: das Onboarding kennt keinen Modellzustand mehr (#982 Schnitt 2, ADR-22).

Aufruf: python3 scripts/test_onboarding_ohne_modell.py [Wurzel]

Der Hinweis über Apple Intelligence auf Schritt 1 (#342) ist samt Code, Startargument und Texten entfernt. Der
Katalogwächter prüft nur Vollständigkeit; dieser Test prüft die Abwesenheit. Ohne Argument gilt das Repo als Wurzel,
mit Argument ein anderer Stand (RED-Nachweis gegen einen älteren Commit).
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REMOVED_KEYS = (
    "Apple Intelligence is off. Turn it on in Settings",
    "Apple Intelligence is still getting ready.",
    "This device has no Apple Intelligence.",
)
REMOVED_WORDS = ("ModelNote", "modelNote", "onboardingModelReason", "ui-testing-model-reason")
CODE_FOLDERS = ("LooseEnds", "Shared", "LooseEndsTests")


class OnboardingOhneModellTests(unittest.TestCase):
    def test_catalog_has_none_of_the_three_note_keys(self):
        catalog = json.loads((ROOT / "LooseEnds/Resources/Localizable.xcstrings").read_text(encoding="utf-8"))
        left = [key for key in catalog["strings"] for prefix in REMOVED_KEYS if key.startswith(prefix)]
        self.assertEqual(left, [], "Hinweisschlüssel stehen noch im Katalog")

    def test_app_and_unit_test_code_name_no_model_note(self):
        hits = []
        for folder in CODE_FOLDERS:
            for path in sorted((ROOT / folder).rglob("*.swift")):
                text = path.read_text(encoding="utf-8")
                hits += [f"{path.relative_to(ROOT)}: {word}" for word in REMOVED_WORDS if word in text]
        self.assertEqual(hits, [], "Modellhinweis noch im Code")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        ROOT = Path(sys.argv.pop(1)).resolve()
    unittest.main()
