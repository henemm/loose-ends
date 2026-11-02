"""Tests für asc_header_upload.py: Kopfbilder in Apples Asset-Bibliothek legen, nie platzieren (#772, Teil B).

Gegen einen Attrappen-Client mit Zustand: geprüft wird die Form der Aufrufe, nicht Apples Antwort. Ob Apple die Bilder
annimmt, zeigt nur der echte Lauf `aktion=hochladen`.

Aufruf: python3 -m unittest scripts/test_asc_header_upload.py
"""
import copy
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from asc_wait_build import Fatal  # noqa: E402

try:
    import asc_header_upload as hu
except ModuleNotFoundError:
    hu = None

APP = "APP1"
SPECS = [{"category": "HEADER_16_9", "width": 5244, "height": 2950},
         {"category": "HEADER_21_9", "width": 3840, "height": 1646}]
NAMES = [("hell-16x9", 5244, 2950), ("dunkel-16x9", 5244, 2950), ("hell-21x9", 3840, 1646), ("dunkel-21x9", 3840, 1646)]


class FakeClient:
    """Nachbau mit Zustand: Anlegen vergibt eine Kennung, `uploaded: true` setzt den Zustand auf PREPARE_FOR_SUBMISSION."""

    def __init__(self, specs=SPECS, images=(), placements=()):
        self.specs = copy.deepcopy(list(specs))
        self.images = {item["id"]: copy.deepcopy(item) for item in images}
        self.placements = list(placements)
        self.calls = []

    def get(self, path):
        self.calls.append(("GET", path))
        if path == "/v1/appAssetLibraryRefData":
            return {"imageSpecs": self.specs}
        if path == f"/v1/apps/{APP}/assetLibrary":
            return {"images": list(self.images.values()), "placements": self.placements}
        if path.startswith("/v1/appAssetLibraryImages/"):
            return self.images[path.rsplit("/", 1)[1]]
        raise AssertionError(f"unbekannter Pfad {path}")

    def post(self, path, body):
        self.calls.append(("POST", path, body))
        assert path == "/v1/appAssetLibraryImages", path
        new = {"id": f"I{len(self.images) + 1}", "referenceName": body["referenceName"], "state": "AWAITING_UPLOAD",
               "uploadOperations": [{"url": "https://upload.test/x"}]}
        self.images[new["id"]] = new
        return new

    def put(self, url, data):
        self.calls.append(("PUT", url, len(data)))

    def patch(self, path, body):
        self.calls.append(("PATCH", path, body))
        item = self.images[path.rsplit("/", 1)[1]]
        if body.get("uploaded"):
            item["state"] = "PREPARE_FOR_SUBMISSION"
        return item

    def writes(self):
        return [call for call in self.calls if call[0] != "GET"]


class NeedsModule(unittest.TestCase):
    def setUp(self):
        if hu is None:
            self.fail("scripts/asc_header_upload.py fehlt")
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        self.files = []
        for reference, width, height in NAMES:
            path = self.root / f"{reference}.png"
            path.write_bytes(b"png-" + reference.encode())
            self.files.append({"path": path, "reference": reference, "width": width, "height": height})

    def run_upload(self, client):
        return hu.upload(client, APP, self.files, sleep=lambda seconds: None)


class UploadTests(NeedsModule):
    def test_stops_without_matching_spec(self):
        client = FakeClient(specs=[{"category": "HEADER_16_9", "width": 1000, "height": 500}])
        with self.assertRaises(Fatal) as caught:
            self.run_upload(client)
        self.assertEqual(client.writes(), [])
        self.assertIn("HEADER_16_9", str(caught.exception))
        self.assertIn("1000", str(caught.exception))

    def test_never_places_or_submits(self):
        client = FakeClient()
        self.run_upload(client)
        for reference, _, _ in NAMES:
            posts = [c for c in client.calls if c[0] == "POST" and c[2]["referenceName"] == reference]
            self.assertEqual(len(posts), 1, reference)
        self.assertEqual(len([c for c in client.calls if c[0] == "PUT"]), 4)
        patches = [c for c in client.calls if c[0] == "PATCH"]
        self.assertEqual(len(patches), 4)
        self.assertTrue(all(c[2].get("uploaded") is True for c in patches))
        paths = " ".join(str(c[1]) for c in client.calls)
        self.assertNotIn("appAssetLibraryPlacements", paths)
        self.assertNotIn("Submission", paths)
        self.assertNotIn("appAssetLibraryPlacements", Path(hu.__file__).read_text())

    def test_skips_existing_reference_name(self):
        existing = [{"id": "X1", "referenceName": "hell-16x9", "state": "PREPARE_FOR_SUBMISSION"}]
        client = FakeClient(images=existing)
        self.run_upload(client)
        created = [c[2]["referenceName"] for c in client.calls if c[0] == "POST"]
        self.assertNotIn("hell-16x9", created)
        self.assertEqual(len(created), 3)

    def test_state_check_reads_ready_state(self):
        names = [reference for reference, _, _ in NAMES]
        ready = {"images": [{"id": f"I{i}", "referenceName": n, "state": "PREPARE_FOR_SUBMISSION"}
                            for i, n in enumerate(names)], "placements": []}
        self.assertEqual(hu.check_state(ready, names), "bereit")
        waiting = copy.deepcopy(ready)
        waiting["images"][2]["state"] = "AWAITING_UPLOAD"
        with self.assertRaises(Fatal):
            hu.check_state(waiting, names)
        placed = copy.deepcopy(ready)
        placed["placements"] = [{"id": "P1"}]
        with self.assertRaises(Fatal):
            hu.check_state(placed, names)
        missing = copy.deepcopy(ready)
        missing["images"].pop()
        with self.assertRaises(Fatal):
            hu.check_state(missing, names)


if __name__ == "__main__":
    unittest.main()
