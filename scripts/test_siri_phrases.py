"""Tests: Siri-Sätze, deutsche Übersetzungen und Watch-Bundle passen zusammen (#355).

Aufruf: python3 scripts/test_siri_phrases.py

Siri liest die Sätze aus `LooseEndsShortcuts` und die deutschen Fassungen aus `AppShortcuts.xcstrings`. Fehlt ein
Schlüssel, versteht eine deutsche Siri den Satz nicht; ein Schlüssel ohne Satz ist toter Text. Die Watch erbt nichts
vom iPhone (WWDC23 10102, SiriKit „Specifying synonyms for your app name“): Katalog, `InfoPlist.strings` und die
Ersatznamen müssen im Watch-Target selbst stehen. Bis #355 enthielt das Watch-Paket keinen einzigen `.lproj`-Ordner.
"""
import fnmatch
import json
import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
INTENT = ROOT / "Shared/Intents/CaptureTextIntent.swift"
CATALOG = ROOT / "LooseEnds/Resources/AppShortcuts.xcstrings"
RESOURCES = "LooseEnds/Resources"
WATCH_RESOURCES = ["AppShortcuts.xcstrings", "Localizable.xcstrings", "de.lproj/InfoPlist.strings",
                   "en.lproj/InfoPlist.strings"]


def phrases(swift):
    """Die Sätze aus `phrases: [...]`, in der Schreibweise der Katalogschlüssel."""
    block = re.search(r"phrases:\s*\[(.*?)\]", swift, re.S)
    if not block:
        return []
    found = re.findall(r'"((?:[^"\\]|\\.)*)"', block.group(1))
    return [p.replace(r"\(.applicationName)", "${applicationName}") for p in found]


def catalog_problems(sentences, catalog):
    """Jeder Satz genau ein Schlüssel mit fertiger deutscher Fassung, kein Schlüssel ohne Satz."""
    strings = catalog.get("strings", {})
    problems = []
    for sentence in sentences:
        unit = strings.get(sentence, {}).get("localizations", {}).get("de", {}).get("stringUnit", {})
        if unit.get("state") != "translated" or not unit.get("value"):
            problems.append(f"{sentence!r}: keine fertige deutsche Fassung im Katalog")
    for key in sorted(set(strings) - set(sentences)):
        problems.append(f"{key!r}: Schlüssel ohne Satz im Code (veraltet)")
    return problems


def included(sources, file):
    """Führt eine Quellangabe des Targets `RESOURCES/file`?"""
    for source in sources:
        if isinstance(source, str):
            if source == RESOURCES or source == f"{RESOURCES}/{file}":
                return True
            continue
        if source.get("path") == f"{RESOURCES}/{file}":
            return True
        if source.get("path") == RESOURCES:
            includes = source.get("includes")
            if includes is None or any(fnmatch.fnmatch(file, pattern) for pattern in includes):
                return True
    return False


def load():
    return (INTENT.read_text(), json.loads(CATALOG.read_text()),
            yaml.safe_load((ROOT / "project.yml").read_text()))


class SiriPhraseTests(unittest.TestCase):
    def setUp(self):
        self.swift, self.catalog, self.project = load()
        self.sentences = phrases(self.swift)

    def test_every_phrase_has_one_german_key_and_no_key_is_stale(self):
        self.assertEqual(catalog_problems(self.sentences, self.catalog), [])

    def test_stale_key_is_reported(self):
        catalog = {"strings": {"Old ${applicationName}": {"localizations": {
            "de": {"stringUnit": {"state": "translated", "value": "Alt ${applicationName}"}}}}}}
        self.assertEqual(catalog_problems([], catalog), ["'Old ${applicationName}': Schlüssel ohne Satz im Code (veraltet)"])

    def test_phrase_list_has_english_and_german_including_erfasse_in(self):
        self.assertIn("Capture with ${applicationName}", self.sentences)
        german = [self.catalog["strings"][s]["localizations"]["de"]["stringUnit"]["value"]
                  for s in self.sentences if s in self.catalog["strings"]]
        self.assertIn("Erfasse in ${applicationName}", german)
        self.assertEqual(len(german), len(self.sentences))

    def test_watch_target_carries_catalogs_and_infoplist_strings(self):
        sources = self.project["targets"]["LooseEndsWatch"]["sources"]
        missing = [f for f in WATCH_RESOURCES if not included(sources, f)]
        self.assertEqual(missing, [], "Watch-Target führt diese Sprachdateien nicht")
        self.assertFalse(included(sources, "Assets.xcassets"), "iOS-Assets gehören nicht ins Watch-Paket")

    def test_watch_infoplist_declares_the_same_siri_names_as_the_app(self):
        app = self.project["targets"]["LooseEnds"]["info"]["properties"]
        watch = self.project["targets"]["LooseEndsWatch"]["info"]["properties"]
        for key in ("CFBundleSpokenName", "INAlternativeAppNames"):
            self.assertIn(key, watch)
            self.assertEqual(watch[key], app[key], f"{key}: Watch weicht von der App ab")

    def test_watch_is_entitled_for_siri_like_the_app(self):
        # Build 52: without it Siri on the watch did not know the app's name („Los Angeles“), as on the iPhone in #347.
        for name in ("LooseEnds", "LooseEndsWatch"):
            properties = self.project["targets"][name]["entitlements"]["properties"]
            self.assertIs(properties.get("com.apple.developer.siri"), True, f"{name}: keine Siri-Berechtigung")


if __name__ == "__main__":
    unittest.main()
