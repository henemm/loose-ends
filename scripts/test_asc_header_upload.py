"""Tests für asc_header_upload.py: Kopfbilder in Apples Asset-Bibliothek legen, nie platzieren (#772, Teil B).

Die Attrappe liefert Apples dokumentierte Antwortform (App Store Connect API 4.5.0): Referenzdaten als Einzeldatensatz
`appAssetLibraryRefData/1`, Spec-Maße als Spannen, eigene Bibliothek-id, Bilder und Platzierungen als Unterpfade, Zustand
`FAILED` mit `stateDetails`. Geprüft wird die Form der Aufrufe, nicht Apples Annahme: ob Apple die Bilder nimmt, zeigt nur der
echte Lauf.

Aufruf: python3 -m unittest scripts/test_asc_header_upload.py
"""
import contextlib
import copy
import io
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

APP, LIBRARY = "APP1", "LIB1"
HEADER_TYPE, CATEGORY = "PRODUCT_PAGE_HEADER_ASSET", "CREATIVE_ASSETS"
WIDE = {"specId": "S169", "alphaAllowed": False, "fileExtensions": ["png"], "compatiblePlacementTypes": [HEADER_TYPE],
        "dimensions": {"minWidth": 5000, "maxWidth": 5300, "minHeight": 2900, "maxHeight": 3000}}
ULTRA = {"specId": "S219", "alphaAllowed": False, "fileExtensions": ["png"], "compatiblePlacementTypes": [HEADER_TYPE],
         "dimensions": {"minWidth": 3840, "maxWidth": 3840, "minHeight": 1600, "maxHeight": 1700}}
OTHER = {"specId": "SX", "compatiblePlacementTypes": ["SEARCH_RESULT_ASSET"],
         "dimensions": {"minWidth": 5000, "maxWidth": 5300, "minHeight": 2900, "maxHeight": 3000}}
PLACEMENT_TYPES = [{"placementType": HEADER_TYPE, "acceptsAssetCategories": [CATEGORY]},
                   {"placementType": "SEARCH_RESULT_ASSET", "acceptsAssetCategories": ["OTHER_ASSETS"]}]
NAMES = [("hell-16x9", 5244, 2950), ("dunkel-16x9", 5244, 2950), ("hell-21x9", 3840, 1646), ("dunkel-21x9", 3840, 1646)]


class FakeClient:
    """Nachbau in Apples Form, mit Zustand: Anlegen vergibt eine Kennung, `uploaded: true` führt über UPLOAD_COMPLETE zu
    PREPARE_FOR_SUBMISSION (oder, für `fail`, zu FAILED). Jeder Pfad außerhalb der dokumentierten bricht den Test."""

    def __init__(self, specs=(WIDE, ULTRA, OTHER), images=(), placements=None, fail=()):
        self.refdata = {"id": "1", "imageSpecs": copy.deepcopy(list(specs)), "placementTypes": copy.deepcopy(PLACEMENT_TYPES)}
        self.images = {item["id"]: copy.deepcopy(item) for item in images}
        self.placements = placements or {}
        self.fail = set(fail)
        self.calls = []
        self.polls = {}

    def get(self, path):
        self.calls.append(("GET", path))
        if path == "/v1/appAssetLibraryRefData/1":
            return copy.deepcopy(self.refdata)
        if path == f"/v1/apps/{APP}/assetLibrary":
            return {"id": LIBRARY}
        if path == f"/v1/appAssetLibraries/{LIBRARY}/images":
            return {"items": copy.deepcopy(list(self.images.values()))}
        parts = path.split("/")
        if len(parts) == 5 and parts[:3] == ["", "v1", "appAssetLibraryImages"] and parts[4] == "placements":
            return {"items": list(self.placements.get(parts[3], []))}
        if len(parts) == 4 and parts[:3] == ["", "v1", "appAssetLibraryImages"]:
            return self.advance(parts[3])
        raise AssertionError(f"unbekannter Pfad {path}")

    def advance(self, image_id):
        item = self.images[image_id]
        if item["state"] == "UPLOAD_COMPLETE":
            self.polls[image_id] = self.polls.get(image_id, 0) + 1
            if self.polls[image_id] >= 2:
                failed = item["referenceName"] in self.fail
                item["state"] = "FAILED" if failed else "PREPARE_FOR_SUBMISSION"
                if failed:
                    item["stateDetails"] = "Bild entspricht keiner Spec"
        return copy.deepcopy(item)

    def post(self, path, attributes, relationships):
        self.calls.append(("POST", path, attributes, relationships))
        assert path == "/v1/appAssetLibraryImages", path
        new = {"id": f"I{len(self.images) + 1}", "referenceName": attributes["referenceName"], "state": "AWAITING_UPLOAD",
               "uploadOperations": [{"method": "PUT", "url": "https://upload.test/x", "offset": 0,
                                     "length": attributes["fileSize"], "requestHeaders": []}]}
        self.images[new["id"]] = new
        return copy.deepcopy(new)

    def put(self, url, data, headers=None):
        self.calls.append(("PUT", url, len(data)))

    def patch(self, path, attributes):
        self.calls.append(("PATCH", path, attributes))
        item = self.images[path.rsplit("/", 1)[1]]
        if attributes.get("uploaded"):
            item["state"] = "UPLOAD_COMPLETE"
        return copy.deepcopy(item)

    def writes(self):
        return [call for call in self.calls if call[0] != "GET"]

    def posts(self):
        return [call for call in self.calls if call[0] == "POST"]


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

    def run_upload(self, client, files=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            state = hu.upload(client, APP, files or self.files, sleep=lambda seconds: None)
        return state, out.getvalue()


class MatchTests(NeedsModule):
    def test_refdata_read_as_single_record(self):
        client = FakeClient()
        self.run_upload(client)
        gets = [call[1] for call in client.calls if call[0] == "GET"]
        self.assertIn("/v1/appAssetLibraryRefData/1", gets)
        self.assertNotIn("/v1/appAssetLibraryRefData", gets)

    def test_match_by_dimension_range_and_placement(self):
        found, unmatched = hu.match_specs(FakeClient().refdata, self.files)
        self.assertEqual(unmatched, [])
        self.assertEqual(found, {name: CATEGORY for name, _, _ in NAMES})
        edge = [{"reference": "knapp", "width": 5301, "height": 2950}]  # eine Spanne zu breit
        found, unmatched = hu.match_specs(FakeClient().refdata, edge)
        self.assertEqual(found, {})
        self.assertEqual([item["reference"] for item in unmatched], ["knapp"])
        other = [{"reference": "nur-suche", "width": 5244, "height": 2950}]  # passt nur zu einer Spec ohne Kopf-Platzierung
        refdata = FakeClient(specs=[OTHER]).refdata
        self.assertEqual(hu.match_specs(refdata, other), ({}, other))

    def test_stops_without_matching_spec(self):
        client = FakeClient(specs=[{"specId": "SZ", "compatiblePlacementTypes": [HEADER_TYPE],
                                    "dimensions": {"minWidth": 1000, "maxWidth": 1000, "minHeight": 500, "maxHeight": 500}}])
        with self.assertRaises(Fatal) as caught:
            self.run_upload(client)
        self.assertEqual(client.writes(), [])
        self.assertIn("SZ", str(caught.exception))
        self.assertIn("1000", str(caught.exception))

    def test_partial_match_uploads_fitting_and_reports_rest(self):
        client = FakeClient(specs=[ULTRA])
        state, out = self.run_upload(client)
        created = sorted(call[2]["referenceName"] for call in client.posts())
        self.assertEqual(created, ["dunkel-21x9", "hell-21x9"])
        self.assertEqual(state, "bereit")
        for name in ("hell-16x9", "dunkel-16x9"):
            warning = [line for line in out.splitlines() if line.startswith("::warning::") and name in line]
            self.assertEqual(len(warning), 1, name)
            self.assertIn("5244x2950", warning[0])


class UploadTests(NeedsModule):
    def test_uses_library_id_and_relationship(self):
        client = FakeClient()
        self.run_upload(client)
        gets = [call[1] for call in client.calls if call[0] == "GET"]
        self.assertIn(f"/v1/appAssetLibraries/{LIBRARY}/images", gets)
        self.assertEqual(len(client.posts()), 4)
        for call in client.posts():
            self.assertEqual(call[3], {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": LIBRARY}}})
            self.assertEqual(call[2]["category"], CATEGORY)
            self.assertIn("fileName", call[2])
            self.assertIn("fileSize", call[2])

    def test_skips_existing_reference_name(self):
        existing = [{"id": "X1", "referenceName": "hell-16x9", "state": "PREPARE_FOR_SUBMISSION"}]
        client = FakeClient(images=existing)
        self.run_upload(client)
        created = [call[2]["referenceName"] for call in client.posts()]
        self.assertNotIn("hell-16x9", created)
        self.assertEqual(len(created), 3)

    def test_never_places_or_submits(self):
        client = FakeClient()
        self.run_upload(client)
        for reference, _, _ in NAMES:
            posts = [c for c in client.posts() if c[2]["referenceName"] == reference]
            self.assertEqual(len(posts), 1, reference)
        self.assertEqual(len([c for c in client.calls if c[0] == "PUT"]), 4)
        patches = [c for c in client.calls if c[0] == "PATCH"]
        self.assertEqual(len(patches), 4)
        self.assertTrue(all(c[2].get("uploaded") is True for c in patches))
        self.assertEqual({c[0] for c in client.writes()}, {"POST", "PUT", "PATCH"})
        paths = " ".join(str(c[1]) for c in client.calls)
        self.assertNotIn("appAssetLibraryPlacements", paths)
        self.assertNotIn("Submission", paths)
        self.assertNotIn("appAssetLibraryPlacements", Path(hu.__file__).read_text())


class StateTests(NeedsModule):
    def test_wait_reaches_ready_and_stops_on_failed(self):
        client = FakeClient(fail=["kaputt"], images=[
            {"id": "A", "referenceName": "gut", "state": "AWAITING_UPLOAD"},
            {"id": "B", "referenceName": "kaputt", "state": "AWAITING_UPLOAD"}])
        client.patch("/v1/appAssetLibraryImages/A", {"uploaded": True})
        hu.wait_ready(client, "A", lambda seconds: None)
        self.assertEqual(client.images["A"]["state"], "PREPARE_FOR_SUBMISSION")
        client.patch("/v1/appAssetLibraryImages/B", {"uploaded": True})
        before = len(client.calls)
        with self.assertRaises(Fatal) as caught:
            hu.wait_ready(client, "B", lambda seconds: None)
        self.assertIn("Bild entspricht keiner Spec", str(caught.exception))
        self.assertLess(len(client.calls) - before, 5)  # bricht beim ersten FAILED ab, pollt nicht weiter

    def test_state_check_reads_ready_state(self):
        names = [reference for reference, _, _ in NAMES]
        images = [{"id": f"I{i}", "referenceName": n, "state": "PREPARE_FOR_SUBMISSION"} for i, n in enumerate(names)]
        self.assertEqual(hu.check_state(FakeClient(images=images), LIBRARY, names), "bereit")
        waiting = copy.deepcopy(images)
        waiting[2]["state"] = "AWAITING_UPLOAD"
        with self.assertRaises(Fatal):
            hu.check_state(FakeClient(images=waiting), LIBRARY, names)
        with self.assertRaises(Fatal):
            hu.check_state(FakeClient(images=images, placements={"I1": [{"id": "P1"}]}), LIBRARY, names)
        with self.assertRaises(Fatal):
            hu.check_state(FakeClient(images=images[:-1]), LIBRARY, names)


class LesenTests(NeedsModule):
    def test_lesen_prints_raw_specs_and_never_writes(self):
        images = [{"id": "I1", "referenceName": "hell-21x9", "state": "FAILED", "stateDetails": "x"}]
        client = FakeClient(images=images, placements={"I1": [{"id": "P1"}, {"id": "P2"}]})
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            hu.lesen(client, APP)
        text = out.getvalue()
        self.assertEqual(client.writes(), [])
        for needle in ("S169", "S219", "5000", "5300", "2900", "3000", "3840", "1600", "1700", HEADER_TYPE,
                       "SEARCH_RESULT_ASSET", CATEGORY, "OTHER_ASSETS", "hell-21x9", "FAILED", "imageSpecs"):
            self.assertIn(needle, text, needle)
        self.assertRegex(text, r"platzierungen=2")


if __name__ == "__main__":
    unittest.main()
