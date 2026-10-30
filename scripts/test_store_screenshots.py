"""Tests für store_screenshots.py: Store-Bilder prüfen, benennen und im Manifest verzeichnen (#742, Schnitt 1).

`sips` und der Export sind durch Funktionen ersetzt, damit nur die Regeln geprüft werden.

Aufruf: python3 -m unittest scripts/test_store_screenshots.py
"""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
try:
    import store_screenshots as ss
except ModuleNotFoundError:
    ss = None

ORDER = ["01-start", "02-erfassen", "03-neu", "04-detail", "05-erledigt"]
IPHONE = (1206, 2622)
IPAD = (2064, 2752)


class NeedsModule(unittest.TestCase):
    def setUp(self):
        if ss is None:
            self.fail("scripts/store_screenshots.py fehlt")
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        self.out = self.root / "out"

    def attachments(self, names=ORDER):
        """Anhangsname `store-<nn>-<name>` → Datei im Export."""
        found = {}
        for name in names:
            path = self.root / f"store-{name}.png"
            path.write_bytes(b"png")
            found[f"store-{name}"] = path
        return found

    @staticmethod
    def info(size, alpha=False):
        return lambda path: (size[0], size[1], alpha)

    @staticmethod
    def keep(path):
        """Entfernen des Alphakanals ist hier ein No-op; `info` meldet den Zustand danach."""


class FinishDeviceTests(NeedsModule):
    def test_names_follow_order(self):
        written = ss.finish_device("iphone", self.attachments(), self.out, self.info(IPHONE), self.keep)
        self.assertEqual([p.name for p in written], [f"{n}.png" for n in ORDER])
        self.assertTrue(all(p.parent == self.out / "iphone" for p in written))

    def test_missing_image_aborts(self):
        with self.assertRaises(ss.StoreError) as ctx:
            ss.finish_device("iphone", self.attachments(ORDER[:4]), self.out, self.info(IPHONE), self.keep)
        self.assertIn("05-erledigt", str(ctx.exception))

    def test_wrong_size_aborts(self):
        with self.assertRaises(ss.StoreError) as ctx:
            ss.finish_device("iphone", self.attachments(), self.out, self.info((1179, 2556)), self.keep)
        self.assertIn("1179x2556", str(ctx.exception))
        self.assertIn("1206x2622", str(ctx.exception))

    def test_alpha_aborts_when_not_removed(self):
        with self.assertRaises(ss.StoreError) as ctx:
            ss.finish_device("iphone", self.attachments(), self.out, self.info(IPHONE, alpha=True), self.keep)
        self.assertIn("Alpha", str(ctx.exception))

    def test_alpha_removal_is_called_for_every_image(self):
        stripped = []
        ss.finish_device("ipad", self.attachments(), self.out, self.info(IPAD), stripped.append)
        self.assertEqual(len(stripped), 5)

    def test_old_files_removed(self):
        old = self.out / "iphone" / "99-alt.png"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"alt")
        ss.finish_device("iphone", self.attachments(), self.out, self.info(IPHONE), self.keep)
        self.assertFalse(old.exists())


class ManifestTests(NeedsModule):
    def test_manifest_lists_both_sizes(self):
        manifest = ss.build_manifest({"iphone": ORDER, "ipad": ORDER}, commit="abc1234", created="2026-10-30T12:00:00Z")
        self.assertEqual(manifest["sprache"], "de-DE")
        entries = manifest["geraete"]
        self.assertEqual([e["pixel"] for e in entries], ["1206x2622", "2064x2752"])
        for entry in entries:
            self.assertEqual(entry["dateien"], [f"{n}.png" for n in ORDER])
        self.assertEqual(manifest["commit"], "abc1234")
        json.dumps(manifest)

    def test_manifest_without_ipad_is_refused(self):
        with self.assertRaises(ss.StoreError):
            ss.build_manifest({"iphone": ORDER}, commit="abc1234", created="2026-10-30T12:00:00Z")


if __name__ == "__main__":
    unittest.main()
