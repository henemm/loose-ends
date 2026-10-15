"""Kein sichtbares „Kontext“ mehr (#420, Henning 2026-10-15): die App sagt überall „Tags“.

Prüft jeden Strings-Katalog der Ziele: weder ein englischer Schlüssel noch eine Übersetzung nennt
„context“/„Kontext“. Im Code heißt das Modell weiter `TaskContext`; das ist nicht sichtbar.
"""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGS = [p for p in ROOT.glob("*/**/*.xcstrings") if "build" not in p.parts]


def visible_texts(catalog: pathlib.Path):
    strings = json.loads(catalog.read_text(encoding="utf-8"))["strings"]
    for key, entry in strings.items():
        yield key
        for localization in entry.get("localizations", {}).values():
            unit = localization.get("stringUnit")
            if unit:
                yield unit.get("value", "")
            for variants in localization.get("variations", {}).values():
                for variant in variants.values():
                    yield variant.get("stringUnit", {}).get("value", "")


class TagsWordingTests(unittest.TestCase):
    def test_catalogs_found(self):
        self.assertTrue(CATALOGS, "keine .xcstrings gefunden")

    def test_no_context_in_visible_text(self):
        hits = [(c.relative_to(ROOT).as_posix(), t) for c in CATALOGS for t in visible_texts(c)
                if "context" in t.lower() or "kontext" in t.lower()]
        self.assertEqual(hits, [], "sichtbarer Text nennt noch Kontext statt Tag")


if __name__ == "__main__":
    unittest.main()
