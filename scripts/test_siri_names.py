"""Tests für Siri-Sätze und App-Namen-Synonyme (#353).

Aufruf: python3 scripts/test_siri_names.py
Siri auf Deutsch hörte „Loose End“ und fand keine App. Ob Siri die Synonyme dann wirklich nutzt, zeigt
nur das Gerät; diese Tests halten fest, dass jeder Satz und jedes Synonym eine deutsche Fassung hat.
"""
import json
import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
INTENT = ROOT / "Shared" / "Intents" / "CaptureTextIntent.swift"
SHORTCUTS = ROOT / "LooseEnds" / "Resources" / "AppShortcuts.xcstrings"
INFOPLIST = ROOT / "LooseEnds" / "Resources" / "InfoPlist.xcstrings"
PROJECT = ROOT / "project.yml"


def phrases():
    """The App Shortcut phrases as their catalog keys (`\\(.applicationName)` becomes `${applicationName}`)."""
    source = INTENT.read_text()
    block = re.search(r"phrases:\s*\[(.*?)\]", source, re.S).group(1)
    return [p.replace("\\(.applicationName)", "${applicationName}") for p in re.findall(r'"((?:[^"\\]|\\.)*)"', block)]


def value(entry, language):
    return entry.get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value")


class SiriNamesTests(unittest.TestCase):
    def test_every_phrase_has_a_german_version_with_the_app_name(self):
        strings = json.loads(SHORTCUTS.read_text())["strings"]
        found = phrases()
        self.assertGreaterEqual(len(found), 3)
        for phrase in found:
            with self.subTest(phrase=phrase):
                self.assertIn("${applicationName}", phrase)
                german = value(strings.get(phrase, {}), "de")
                self.assertIsNotNone(german, f"keine deutsche Fassung für {phrase!r}")
                self.assertIn("${applicationName}", german)

    def test_app_name_synonyms_are_localized_in_english_and_german(self):
        app = yaml.safe_load(PROJECT.read_text())["targets"]["LooseEnds"]["info"]["properties"]
        synonyms = app["INAlternativeAppNames"]
        self.assertLessEqual(len(synonyms), 3, "Apple erlaubt höchstens drei Synonyme je Sprache")
        strings = json.loads(INFOPLIST.read_text())["strings"]
        for entry in synonyms:
            for key in ("INAlternativeAppName", "INAlternativeAppNamePronunciationHint"):
                variable = entry[key]
                with self.subTest(variable=variable):
                    self.assertIn(variable, strings, f"{variable} fehlt in InfoPlist.xcstrings")
                    for language in ("en", "de"):
                        self.assertTrue(value(strings[variable], language), f"{variable} ohne {language}")

    def test_spoken_name_is_set_and_localized(self):
        app = yaml.safe_load(PROJECT.read_text())["targets"]["LooseEnds"]["info"]["properties"]
        self.assertEqual(app.get("CFBundleSpokenName"), "Loose Ends")
        spoken = json.loads(INFOPLIST.read_text())["strings"]["CFBundleSpokenName"]
        for language in ("en", "de"):
            self.assertTrue(value(spoken, language), f"CFBundleSpokenName ohne {language}")

    def test_intents_extension_supports_add_tasks_and_app_has_siri(self):
        project = yaml.safe_load(PROJECT.read_text())
        targets = project["targets"]
        ext = targets["LooseEndsIntents"]["info"]["properties"]["NSExtension"]
        self.assertEqual(ext["NSExtensionPointIdentifier"], "com.apple.intents-service")
        self.assertIn("INAddTasksIntent", ext["NSExtensionAttributes"]["IntentsSupported"])
        app = targets["LooseEnds"]
        self.assertTrue(app["entitlements"]["properties"].get("com.apple.developer.siri"))
        self.assertTrue(app["info"]["properties"].get("NSSiriUsageDescription"))
        self.assertIn("LooseEndsIntents", [d.get("target") for d in app["dependencies"]])

    def test_german_synonyms_cover_what_siri_heard(self):
        strings = json.loads(INFOPLIST.read_text())["strings"]
        german = {value(e, "de") for k, e in strings.items() if k.startswith("LE_APP_SYNONYM") and not k.endswith("_HINT")}
        self.assertIn("Loose End", german)


if __name__ == "__main__":
    unittest.main()
