"""Tests: der Einleitungssatz in README.md und CLAUDE.md folgt dem freigegebenen Kern (#837 Schnitt 4).

Aufruf: python3 scripts/test_claim_satz.py

Der Store-Untertitel („Say it. Clear your head.“) ist freigegeben, „Sortiert“ ist verworfen (Henning, 2026-11-04).
Die erste Satzzeile der beiden Dateien darf das Verworfene nicht mehr versprechen.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLAIM = "Say it. Clear your head."
DISCARDED = "it's sorted"


def line3(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8").splitlines()[2]


class ClaimSatzTests(unittest.TestCase):
    def test_readme_zeile_3_ist_der_kern(self):
        self.assertEqual(CLAIM, line3("README.md"))

    def test_claude_md_zeile_3_beginnt_mit_dem_kern(self):
        self.assertTrue(line3("CLAUDE.md").startswith(CLAIM + " Task capture with on-device Apple Intelligence"))

    def test_verworfenes_versprechen_steht_in_keiner_der_beiden(self):
        for name in ("README.md", "CLAUDE.md"):
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertNotIn(DISCARDED, text, name)


if __name__ == "__main__":
    unittest.main()
