"""Tests für store_header.py: Kopfbild für den App Store, deterministisch gezeichnet (#772, Teil A).

Aufruf: python3 -m unittest scripts/test_store_header.py
"""
import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
try:
    import store_header as sh
except ModuleNotFoundError:
    sh = None

SIZES = {"16x9": (5244, 2950), "21x9": (3840, 1646)}
SURFACE = {"hell": (0x0F, 0x6E, 0x73), "dunkel": (0x10, 0x18, 0x19)}
THREAD = {"hell": (0xF4, 0xF3, 0xEE), "dunkel": (0x5F, 0xC4, 0xC9)}
MARGIN = 0.12


class NeedsBuild(unittest.TestCase):
    """Zeichnet einmal pro Klasse; 5244 × 2950 ist teuer genug."""

    @classmethod
    def setUpClass(cls):
        if sh is None:
            raise AssertionError("scripts/store_header.py fehlt")
        cls.root = Path(tempfile.mkdtemp())
        cls.out = cls.root / "header"
        sh.build(cls.out)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.root, ignore_errors=True)

    def image(self, variant, ratio):
        from PIL import Image
        return Image.open(self.out / f"{variant}-{ratio}.png")


class HeaderTests(NeedsBuild):
    def test_sizes_and_manifest(self):
        manifest = json.loads((self.out / "manifest.json").read_text())
        entries = {entry["file"]: entry for entry in manifest["files"]}
        self.assertEqual(len(entries), 4)
        for variant in SURFACE:
            for ratio, (w, h) in SIZES.items():
                name = f"{variant}-{ratio}.png"
                self.assertEqual(self.image(variant, ratio).size, (w, h), name)
                entry = entries[name]
                self.assertEqual((entry["width"], entry["height"]), (w, h))
                self.assertEqual(entry["sha256"], hashlib.sha256((self.out / name).read_bytes()).hexdigest())

    def test_no_alpha(self):
        for variant in SURFACE:
            for ratio in SIZES:
                image = self.image(variant, ratio)
                self.assertEqual(image.mode, "RGB", f"{variant}-{ratio}")
                self.assertNotIn("transparency", image.info)

    def test_colors_light_and_dark(self):
        for variant in SURFACE:
            for ratio in SIZES:
                image = self.image(variant, ratio).convert("RGB")
                w, h = image.size
                self.assertEqual(image.getpixel((2, 2)), SURFACE[variant], f"{variant}-{ratio} Fläche")
                self.assertEqual(image.getpixel((w - 3, h - 3)), SURFACE[variant])
                colors = {color for _, color in image.getcolors(maxcolors=w * h)}
                self.assertIn(THREAD[variant], colors, f"{variant}-{ratio} Faden")

    def test_safe_margin_is_empty(self):
        for variant in SURFACE:
            for ratio in SIZES:
                image = self.image(variant, ratio).convert("RGB")
                w, h = image.size
                mx, my = int(w * MARGIN), int(h * MARGIN)
                bands = [(0, 0, w, my), (0, h - my, w, h), (0, 0, mx, h), (w - mx, 0, w, h)]
                for box in bands:
                    colors = image.crop(box).getcolors(maxcolors=1)
                    self.assertEqual(colors, [((box[2] - box[0]) * (box[3] - box[1]), SURFACE[variant])],
                                     f"{variant}-{ratio} Rand {box}")

    def test_deterministic(self):
        again = self.root / "again"
        sh.build(again)
        for variant in SURFACE:
            for ratio in SIZES:
                name = f"{variant}-{ratio}.png"
                self.assertEqual((again / name).read_bytes(), (self.out / name).read_bytes(), name)
        self.assertEqual((again / "manifest.json").read_bytes(), (self.out / "manifest.json").read_bytes())


if __name__ == "__main__":
    unittest.main()
