"""Tests: jede ausgelieferte Sprache ist vollständig — Berechtigungstexte und String-Kataloge (#342, #756).

Aufruf: python3 scripts/test_catalog_languages.py

Die englischen Berechtigungstexte stehen in project.yml (`info.properties`); ein deutsches Gerät zeigt sie nur
dann deutsch, wenn `de.lproj/InfoPlist.strings` denselben Schlüssel hat, sonst fällt der Dialog auf Englisch zurück
(2026-10-26: Mikrofon, Spracherkennung und Kalender fehlten, auch auf der Watch, die dieselbe Datei bündelt, #355).
Die String-Kataloge sind Quelle `en`; jeder übersetzbare Eintrag braucht einen übersetzten Wert je weiterer Sprache.
Die Sprachen kommen aus `LanguagePacks.shipped` (`shipped_languages.py`), nicht aus einer festen Liste (#756).
Der Lauf braucht kein Xcode; die CI führt alle `scripts/test_*.py` per `unittest discover` aus.
"""
import json
import re
import tempfile
import unittest
from pathlib import Path

import yaml

from shipped_languages import shipped_languages

ROOT = Path(__file__).resolve().parent.parent

LANGUAGES = [code for code in shipped_languages(ROOT) if code != "en"]


def info_plist_strings(lang):
    return ROOT / f"LooseEnds/Resources/{lang}.lproj/InfoPlist.strings"


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


def translated_keys(path):
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


def _is_translated(localization):
    units = list(_units(localization))
    return bool(units) and all(u.get("state") == "translated" and u.get("value", "").strip() for u in units)


def missing_translation(catalog_path, lang):
    """Schlüssel der Katalogdatei, die übersetzt werden sollen und keinen übersetzten Wert in `lang` haben."""
    with open(catalog_path, encoding="utf-8") as handle:
        catalog = json.load(handle)
    missing = []
    for key, entry in catalog["strings"].items():
        if entry.get("shouldTranslate") is False:
            continue
        localized = (entry.get("localizations") or {}).get(lang)
        if localized is None or not _is_translated(localized):
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

    def test_every_usage_description_is_translated(self):
        for lang in LANGUAGES:
            path = info_plist_strings(lang)
            self.assertTrue(path.is_file(), f"{lang}: {path.relative_to(ROOT)} fehlt")
            present = translated_keys(path)
            for target, keys in self.usage.items():
                for key in sorted(keys):
                    with self.subTest(lang=lang, target=target, key=key):
                        self.assertIn(key, present, f"{lang}: {path.relative_to(ROOT)}: {key} fehlt ({target} zeigt den Dialog englisch)")


class CatalogLanguageTests(unittest.TestCase):
    def test_every_catalog_entry_is_translated(self):
        for lang in LANGUAGES:
            for catalog in CATALOGS:
                with self.subTest(lang=lang, catalog=catalog):
                    missing = missing_translation(ROOT / catalog, lang)
                    self.assertEqual(missing, [], f"{lang}: {catalog}: ohne übersetzten Wert, erster Schlüssel: {missing[:1]}")

    def test_a_missing_value_is_found(self):
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
            self.assertEqual(sorted(missing_translation(path, "de")), ["Later", "Open"])


CODE_FOLDERS = ["LooseEnds", "LooseEndsWatch", "Shared"]
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
