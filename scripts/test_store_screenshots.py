"""Tests für store_screenshots.py: Store-Bilder prüfen, benennen und im Manifest verzeichnen (#742, Schnitt 1).

`sips` und der Export sind durch Funktionen ersetzt, damit nur die Regeln geprüft werden.

Aufruf: python3 -m unittest scripts/test_store_screenshots.py
"""
import json
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
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


    def test_failed_check_keeps_previous_folder(self):
        old = self.out / "iphone" / "01-start.png"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"alt")
        with self.assertRaises(ss.StoreError):
            ss.finish_device("iphone", self.attachments(), self.out, self.info((1179, 2556)), self.keep)
        self.assertEqual(old.read_bytes(), b"alt")
        self.assertEqual([p.name for p in self.out.iterdir()], ["iphone"])


class ReadExportTests(NeedsModule):
    def test_duplicate_attachment_aborts(self):
        items = [{"suggestedHumanReadableName": f"store-01-start_{n}_X.png", "exportedFileName": f"{n}.png"}
                 for n in (0, 1)]
        (self.root / "manifest.json").write_text(json.dumps([{"attachments": items}]))
        with self.assertRaises(ss.StoreError) as ctx:
            ss.read_export(self.root)
        self.assertIn("store-01-start", str(ctx.exception))


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


PAPER = (244, 243, 238)
GRIP = (2008, 2696, 2054, 2742)   # gemessener Griff auf den iPad-Bildern: x0, y0, x1, y1 (einschließlich)


def write_png(path, size, color, boxes=()):
    """RGB-PNG ohne Alpha: Fläche `color`, darüber Rechtecke (x0, y0, x1, y1, farbe), Grenzen einschließlich."""
    width, height = size
    rows = [bytearray(bytes(color) * width) for _ in range(height)]
    for x0, y0, x1, y1, fill in boxes:
        for y in range(y0, y1 + 1):
            rows[y][x0 * 3:(x1 + 1) * 3] = bytes(fill) * (x1 - x0 + 1)
    raw = b"".join(b"\0" + bytes(row) for row in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 1)) + chunk(b"IEND", b""))


def pixels(path):
    """Liest ein Bild über `sips` als BMP: Funktion (x, y) → (r, g, b) und alle Pixeldaten zum Vergleich."""
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "bild.bmp"
        subprocess.run(["sips", "-s", "format", "bmp", str(path), "--out", str(bmp)], capture_output=True, check=True)
        data = bmp.read_bytes()
    offset, = struct.unpack_from("<I", data, 10)
    width, height, _, bits = struct.unpack_from("<iiHH", data, 18)
    step, stride = bits // 8, (width * bits // 8 + 3) // 4 * 4

    def at(x, y):
        i = offset + (y if height < 0 else abs(height) - 1 - y) * stride + x * step
        return data[i + 2], data[i + 1], data[i]
    return at, data[offset:]


@unittest.skipUnless(shutil.which("sips"), "sips fehlt (nur macOS)")
class WindowGripTests(NeedsModule):
    """Der graue Bogen des iPadOS-Fenstergriffs unten rechts wird zur Papierfarbe der Umgebung (#742)."""

    def image(self, color, boxes=()):
        path = self.root / "bild.png"
        write_png(path, IPAD, color, boxes)
        return path

    def test_grip_on_plain_paper_becomes_background(self):
        for color in (PAPER, (255, 255, 254)):   # Farbe aus der Umgebung, nicht fest verdrahtet
            with self.subTest(color=color):
                path = self.image(color, [(*GRIP, (142, 142, 147))])
                ss.sips_clear_grip(path)
                at, _ = pixels(path)
                corner = {at(x, y) for y in range(GRIP[1] - 10, IPAD[1]) for x in range(GRIP[0] - 10, IPAD[0])}
                self.assertEqual(corner, {color})

    def test_rest_of_image_untouched(self):
        mark = (10, 20, 30)
        path = self.image(PAPER, [(*GRIP, (142, 142, 147)), (1900, 2600, 1905, 2605, mark)])
        ss.sips_clear_grip(path)
        at, _ = pixels(path)
        self.assertEqual(at(1902, 2602), mark)

    def test_busy_corner_stays_identical(self):
        keys = [(1700 + 90 * i, 2560, 1770 + 90 * i, 2751, (252, 252, 254)) for i in range(4)]
        cases = {
            "Tastatur": self.image((209, 212, 217), keys + [(*GRIP, (142, 142, 147))]),
            "Inhalt links der Ecke": self.image(PAPER, [(1960, 2700, 1995, 2720, (30, 30, 30)), (*GRIP, (142, 142, 147))]),
        }
        for name, path in cases.items():
            with self.subTest(name):
                _, before = pixels(path)
                ss.sips_clear_grip(path)
                _, after = pixels(path)
                self.assertEqual(before, after)

    def test_size_kept_and_no_alpha(self):
        path = self.image(PAPER, [(*GRIP, (142, 142, 147))])
        ss.sips_clear_grip(path)
        self.assertEqual(ss.sips_info(path), (IPAD[0], IPAD[1], False))


class GripHookTests(NeedsModule):
    def test_grip_cleared_on_ipad_only(self):
        for device, size, calls in (("ipad", IPAD, 5), ("iphone", IPHONE, 0)):
            with self.subTest(device):
                cleared = []
                ss.finish_device(device, self.attachments(), self.out, self.info(size), self.keep, cleared.append)
                self.assertEqual(len(cleared), calls)


if __name__ == "__main__":
    unittest.main()
