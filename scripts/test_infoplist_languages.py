"""Tests: Deutsch ist vollständig — Berechtigungstexte und String-Kataloge (#342, Teil 4).

Aufruf: python3 scripts/test_infoplist_languages.py

Die englischen Berechtigungstexte stehen in project.yml (`info.properties`); ein deutsches Gerät zeigt sie nur
dann deutsch, wenn `de.lproj/InfoPlist.strings` denselben Schlüssel hat, sonst fällt der Dialog auf Englisch zurück
(2026-10-26: Mikrofon, Spracherkennung und Kalender fehlten, auch auf der Watch, die dieselbe Datei bündelt, #355).
Die vier String-Kataloge sind Quelle `en`; jeder übersetzbare Eintrag braucht einen übersetzten `de`-Wert.
Der Lauf braucht kein Xcode; die CI führt alle `scripts/test_*.py` per `unittest discover` aus.
"""
import json
import re
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

DE_STRINGS = ROOT / "LooseEnds/Resources/de.lproj/InfoPlist.strings"
CATALOGS = [
    "LooseEnds/Resources/Localizable.xcstrings",
    "LooseEnds/Resources/AppShortcuts.xcstrings",
    "LooseEndsWidgets/Localizable.xcstrings",
    "LooseEndsShare/Localizable.xcstrings",
    "LooseEndsWatchWidgets/Localizable.xcstrings",
]
USAGE_KEY = re.compile(r"^NS\w+UsageDescription$")
STRINGS_LINE = re.compile(r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)


def usage_keys(project):
    """Je Ziel: die `NS*UsageDescription`-Schlüssel aus `info.properties`."""
    result = {}
    for name, target in project["targets"].items():
        properties = (target.get("info") or {}).get("properties", {})
        keys = {key for key in properties if USAGE_KEY.match(key)}
        if keys:
            result[name] = keys
    return result


def german_keys(path):
    """Schlüssel mit nichtleerem Wert in einer InfoPlist.strings."""
    text = path.read_text(encoding="utf-8")
    return {key for key, value in STRINGS_LINE.findall(text) if value.strip()}


def _units(node):
    """Alle `stringUnit` unter einer Lokalisierung, auch in Plural- und Gerätevarianten."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "stringUnit":
                yield value
            else:
                yield from _units(value)


def _has_german(localization):
    units = list(_units(localization))
    return bool(units) and all(u.get("state") == "translated" and u.get("value", "").strip() for u in units)


def missing_german(catalog_path):
    """Schlüssel der Katalogdatei, die übersetzt werden sollen und keinen übersetzten `de`-Wert haben."""
    with open(catalog_path, encoding="utf-8") as handle:
        catalog = json.load(handle)
    missing = []
    for key, entry in catalog["strings"].items():
        if entry.get("shouldTranslate") is False:
            continue
        german = (entry.get("localizations") or {}).get("de")
        if german is None or not _has_german(german):
            missing.append(key)
    return missing


class InfoPlistLanguageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(ROOT / "project.yml", encoding="utf-8") as handle:
            cls.usage = usage_keys(yaml.safe_load(handle))

    def test_project_declares_the_usage_descriptions(self):
        """Ohne Schlüssel prüft der Test nichts: Mikrofon, Sprache und Kalender müssen vorkommen."""
        app = self.usage.get("LooseEnds", set())
        for key in ("NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
                    "NSCalendarsFullAccessUsageDescription"):
            self.assertIn(key, app)

    def test_every_usage_description_has_german(self):
        german = german_keys(DE_STRINGS)
        for target, keys in self.usage.items():
            for key in sorted(keys):
                with self.subTest(target=target, key=key):
                    self.assertIn(key, german, f"{DE_STRINGS.relative_to(ROOT)}: {key} fehlt ({target} zeigt den Dialog englisch)")


class CatalogLanguageTests(unittest.TestCase):
    def test_every_catalog_entry_has_german(self):
        for catalog in CATALOGS:
            with self.subTest(catalog=catalog):
                self.assertEqual(missing_german(ROOT / catalog), [], f"{catalog}: ohne deutschen Wert")

    def test_a_missing_german_value_is_found(self):
        """Selbstprüfung: eine Lücke macht den Test rot, sonst prüfte er nichts."""
        catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {
            "Done": {"localizations": {"de": {"stringUnit": {"state": "translated", "value": "Erledigt"}}}},
            "Open": {"localizations": {"en": {"stringUnit": {"state": "translated", "value": "Open"}}}},
            "Later": {"localizations": {"de": {"stringUnit": {"state": "new", "value": "Später"}}}},
            "%lld": {"shouldTranslate": False},
        }}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "Localizable.xcstrings"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            self.assertEqual(sorted(missing_german(path)), ["Later", "Open"])


CODE_FOLDERS = ["LooseEnds", "Shared"]
# Text-Literale, die SwiftUI und `String(localized:)` im Katalog nachschlagen; Interpolationen (`\(`) sind dynamisch.
LITERAL = re.compile(
    r'(?:String\(localized:\s*|\bText\(|\bButton\(|\bLabel\(|\bLabeledContent\(|navigationTitle\()"((?:[^"\\]|\\.)+)"'
)
# Die Komplikation benennt sich über Modifier, nicht über `Text(`; nur für ihren Ordner gescannt, damit fremde `description(` nicht auffallen (#342 S2).
WATCH_WIDGET_FOLDER = "LooseEndsWatchWidgets"
MODIFIER_LITERAL = re.compile(
    r'\b(?:accessibilityLabel|widgetLabel|configurationDisplayName|description)\("((?:[^"\\]|\\.)+)"'
)


def literals_missing_from_catalog(catalog_path, folders, patterns=(LITERAL,)):
    """Text-Literale im Code, deren Schlüssel im Katalog fehlt (dort steht dann auf jedem Gerät Englisch)."""
    with open(catalog_path, encoding="utf-8") as handle:
        keys = set(json.load(handle)["strings"])
    missing = {}
    for folder in folders:
        for source in sorted(Path(folder).rglob("*.swift")):
            text = source.read_text(encoding="utf-8")
            for match in (m for pattern in patterns for m in pattern.finditer(text)):
                key = match.group(1)
                if "\\(" not in key and key not in keys:
                    missing.setdefault(key, source.relative_to(ROOT) if source.is_relative_to(ROOT) else source)
    return missing


class CodeLiteralTests(unittest.TestCase):
    def test_every_code_literal_has_a_catalog_entry(self):
        missing = literals_missing_from_catalog(
            ROOT / "LooseEnds/Resources/Localizable.xcstrings", [ROOT / folder for folder in CODE_FOLDERS])
        self.assertEqual(missing, {}, "Text im Code ohne Katalogeintrag (zeigt auf Deutsch Englisch)")

    def test_scanner_finds_a_missing_key(self):
        """Selbstprüfung: ein Schlüssel ohne Eintrag wird gemeldet, ein vorhandener nicht."""
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {"Done": {}}}
            (folder / "Localizable.xcstrings").write_text(json.dumps(catalog), encoding="utf-8")
            (folder / "View.swift").write_text(
                'Text("Done")\nString(localized: "Counts")\nText("Hello \\(name)")\n', encoding="utf-8")
            found = literals_missing_from_catalog(folder / "Localizable.xcstrings", [folder])
            self.assertEqual(sorted(found), ["Counts"])


class ComplicationLiteralTests(unittest.TestCase):
    def test_complication_literals_have_a_catalog_entry(self):
        missing = literals_missing_from_catalog(
            ROOT / WATCH_WIDGET_FOLDER / "Localizable.xcstrings", [ROOT / WATCH_WIDGET_FOLDER],
            (LITERAL, MODIFIER_LITERAL))
        self.assertEqual(missing, {}, "Text der Komplikation ohne Katalogeintrag (zeigt auf Deutsch Englisch)")

    def test_modifier_scanner_finds_a_missing_key(self):
        """Selbstprüfung: die vier Modifier melden einen fehlenden Schlüssel, ein vorhandener bleibt still."""
        source = ('.accessibilityLabel("Capture")\ncontent.widgetLabel("Capture")\n'
                  '.configurationDisplayName("Capture")\n.description("Opens capture.")\n')
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            (folder / "View.swift").write_text(source, encoding="utf-8")
            for strings, expected in (({}, ["Capture", "Opens capture."]),
                                      ({"Capture": {}, "Opens capture.": {}}, [])):
                catalog = {"sourceLanguage": "en", "version": "1.0", "strings": strings}
                (folder / "Localizable.xcstrings").write_text(json.dumps(catalog), encoding="utf-8")
                found = literals_missing_from_catalog(folder / "Localizable.xcstrings", [folder], (MODIFIER_LITERAL,))
                self.assertEqual(sorted(found), expected)


if __name__ == "__main__":
    unittest.main()
