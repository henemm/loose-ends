"""Tests: `shipped_languages` liest die ausgelieferten Sprachen aus dem Swift-Code (#756)."""
import shutil
import tempfile
import unittest
from pathlib import Path

from shipped_languages import ROOT, PACK_FILE, ShippedLanguagesError, shipped_languages


def copy_language_folder(target):
    shutil.copytree(ROOT / "Shared/Language", Path(target) / "Shared/Language")


class ShippedLanguagesTests(unittest.TestCase):
    def test_real_file_lists_en_and_de(self):
        self.assertEqual(shipped_languages(ROOT), ["en", "de"])

    def test_missing_code_names_file(self):
        with tempfile.TemporaryDirectory() as folder:
            copy_language_folder(folder)
            german = Path(folder) / "Shared/Language/GermanPack.swift"
            german.write_text(german.read_text(encoding="utf-8").replace('code: "de",', ""), encoding="utf-8")
            with self.assertRaises(ShippedLanguagesError) as raised:
                shipped_languages(folder)
            self.assertIn("GermanPack.swift", str(raised.exception))

    def test_missing_shipped_line_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            copy_language_folder(folder)
            pack = Path(folder) / PACK_FILE
            pack.write_text(pack.read_text(encoding="utf-8").replace("static let shipped", "static let other"), encoding="utf-8")
            with self.assertRaises(ShippedLanguagesError) as raised:
                shipped_languages(folder)
            self.assertIn("LanguagePack.swift", str(raised.exception))

    def test_a_third_language_is_read_in_list_order(self):
        with tempfile.TemporaryDirectory() as folder:
            copy_language_folder(folder)
            language = Path(folder) / "Shared/Language"
            (language / "TestPack.swift").write_text(
                'extension LanguagePack {\n    static let test = LanguagePack(\n        code: "zz",\n')
            pack = language / "LanguagePack.swift"
            pack.write_text(pack.read_text(encoding="utf-8").replace("[.english, .german]", "[.english, .german, .test]"),
                            encoding="utf-8")
            self.assertEqual(shipped_languages(folder), ["en", "de", "zz"])


if __name__ == "__main__":
    unittest.main()
