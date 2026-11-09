"""Tests für asc_store_images.py: Store-Bilder einer Sprache in Apples Asset-Bibliothek legen (#842, 4c-1) und die
englischen auf der en-US-Seite der bearbeitbaren Version platzieren, ordnen und gegenprüfen (4c-2). Nie löschen, nie einreichen,
de-DE nie beschreiben.

Die Attrappe liefert Apples dokumentierte Form (Datenmodell `AppAssetLibraryRefDatum`, gelesen 2026-11-08):
`features[].featureId` mit `placementPolicies[].placementType` und `groupLimits[]` aus `groupIds` und `maxCount`,
`placementTypes[]` mit `placementTypeId` und `acceptsAssetCategories`, `placementProfileGroups[]` mit
`placementProfileGroupId`. Die Gruppennamen sind die echten aus dem Lauf der Store-Probe 42515431363, nicht die veralteten
der Probe-Fixtures. Versionen kommen roh (id + attributes) wie aus `asc_version_texts.app_versions`, Lokalisierungen über
eine übergebene Funktion. Platzierungen folgen „Placing assets on your App Store surfaces“ (gelesen 2026-11-09): Anlegen
`POST /v1/appAssetLibraryPlacements` (Attribute `placementType`, `placementGroup`; Relationen `image`,
`appStoreVersionLocalization`), Ordnen `POST /v1/appAssetLibraryPlacementOrderingRequests` (Attribut `placementGroup`,
Relationen `orderedPlacements`, `appStoreVersionLocalization`), Lesen je Lokalisierung und Gruppe sortiert nach
`placementGroupPosition` ohne Positionsfeld (die Reihenfolge der Antwort ist die Ordnung), Zustand je Platzierung über
`GET /v1/appAssetLibraryPlacements/{id}`, `ACTIVE` wie in der Store-Probe 42519049719. Ob Apple die Bilder nimmt, zeigt nur der
echte Lauf.

Aufruf: python3 -m unittest scripts/test_asc_store_images.py
"""
import contextlib
import copy
import io
import json
import shutil
import struct
import sys
import tempfile
import unittest
import urllib.parse
import zlib
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))

from asc_wait_build import Fatal  # noqa: E402

try:
    import asc_store_images as si
except ModuleNotFoundError:
    si = None

APP, LIBRARY = "APP1", "LIB1"
IPHONE, IPAD, WATCH = "IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE", "IPAD_13_PROFILE", "WATCH_SERIES_10_PROFILE"
SHOT, CATEGORY = "APP_SCREENSHOT", "APP_SCREENSHOTS_AND_PREVIEWS"
EN_NAMES = ([f"en-iphone-{n}" for n in ("01-start", "02-erfassen", "03-neu", "04-detail", "05-erledigt")]
            + [f"en-ipad-{n}" for n in ("01-start", "02-erfassen", "03-neu", "04-detail", "05-erledigt")]
            + ["en-watch-01-jetzt", "en-watch-02-gespeichert"])
IOS = {"id": "V101", "attributes": {"platform": "IOS", "versionString": "1.0.1", "appStoreState": "PREPARE_FOR_SUBMISSION"}}
IOS_OLD = {"id": "V100", "attributes": {"platform": "IOS", "versionString": "1.0", "appStoreState": "READY_FOR_SALE"}}
MAC_OLD = {"id": "M100", "attributes": {"platform": "MAC_OS", "versionString": "1.0", "appStoreState": "READY_FOR_SALE"}}
VERSIONS = [IOS, IOS_OLD, MAC_OLD]
LOC_EN, LOC_DE = "L-en-US", "L-de-DE"
PLACEMENTS = "/v1/appAssetLibraryPlacements"
ORDERING = "/v1/appAssetLibraryPlacementOrderingRequests"
EN_GROUPS = {IPHONE: EN_NAMES[:5], IPAD: EN_NAMES[5:10], WATCH: EN_NAMES[10:]}
DE_COUNTS = {IPHONE: 5, IPAD: 5, WATCH: 2}


def refdata(limits=None, groups=(IPHONE, IPAD, WATCH, "MAC_PROFILE")):
    """Ein Datensatz wie `/v1/appAssetLibraryRefData/1`, flach (id + Attribute). Die Grenzen der eigenen Produktseiten
    (3 je Gruppe) stehen daneben, damit das Skript die der App-Store-Version liest."""
    limits = limits or {group: 10 for group in groups}
    return {"id": "1",
            "features": [
                {"featureId": "CUSTOM_PRODUCT_PAGES", "placementPolicies": [
                    {"placementType": SHOT, "groupLimits": [{"groupIds": list(groups), "maxCount": 3}]}]},
                {"featureId": "APP_STORE_VERSIONS", "placementPolicies": [
                    {"placementType": "PRODUCT_PAGE_HEADER_ASSET", "groupLimits": [{"groupIds": ["DEFAULT_PROFILE"],
                                                                                    "maxCount": 1}]},
                    {"placementType": SHOT, "groupLimits": [{"groupIds": [g], "maxCount": n}
                                                            for g, n in limits.items()]}]}],
            "placementTypes": [{"placementTypeId": SHOT, "acceptsAssetCategories": [CATEGORY]},
                               {"placementTypeId": "PRODUCT_PAGE_HEADER_ASSET",
                                "acceptsAssetCategories": ["CREATIVE_ASSETS"]}],
            "placementProfileGroups": [{"placementProfileGroupId": g, "platform": "IOS"} for g in groups]}


def png(width, height):
    """Kleinste PNG mit echtem Dateikopf (IHDR) im gewünschten Maß; Bildinhalt egal."""
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IEND", b""))


class FakeClient:
    """Nachbau in Apples Form, mit Zustand: Anlegen vergibt eine Kennung, `uploaded: true` führt über UPLOAD_COMPLETE zu
    PREPARE_FOR_SUBMISSION (oder, für `fail`, zu FAILED). Jeder Pfad außerhalb der dokumentierten bricht den Test."""

    def __init__(self, ref=None, images=(), placements=None, fail=(), slots=(), reverse_new=False,
                 ignore_ordering=False, lose=(), placement_fail=(), processing=2):
        self.refdata = ref or refdata()
        self.images = {item["id"]: copy.deepcopy(item) for item in images}
        self.placements = placements or {}
        self.fail = set(fail)
        self.calls = []
        self.polls = {}
        # Platzierungen in Anzeigereihenfolge: id, image, loc, group, state; `lost` = angelegt, aber nie gelistet.
        self.slots = [copy.deepcopy(slot) for slot in slots]
        self.reverse_new, self.ignore_ordering = reverse_new, ignore_ordering
        self.lose, self.placement_fail, self.processing = set(lose), set(placement_fail), processing
        self.next_id = 0

    def get(self, path):
        self.calls.append(("GET", path))
        if path == "/v1/appAssetLibraryRefData/1":
            return copy.deepcopy(self.refdata)
        if path == f"/v1/apps/{APP}/assetLibrary":
            return {"id": LIBRARY}
        if path == f"/v1/appAssetLibraries/{LIBRARY}/images":
            return {"items": copy.deepcopy(list(self.images.values()))}
        base, _, query = path.partition("?")
        parts = base.split("/")
        if len(parts) == 5 and parts[:3] == ["", "v1", "appStoreVersionLocalizations"] and parts[4] == "placements":
            params = dict(urllib.parse.parse_qsl(query))
            assert params.get("sort") == "placementGroupPosition", path
            assert params.get("filter[placementType]") == SHOT, path
            assert params.get("filter[placementGroup]"), path
            return {"items": [self.public(slot) for slot in self.visible(parts[3], params["filter[placementGroup]"])]}
        if query:
            raise AssertionError(f"unbekannter Pfad {path}")
        if len(parts) == 5 and parts[:3] == ["", "v1", "appAssetLibraryImages"] and parts[4] == "placements":
            own = [{"id": slot["id"]} for slot in self.slots if slot["image"] == parts[3] and not slot.get("lost")]
            return {"items": list(self.placements.get(parts[3], [])) + own}
        if len(parts) == 4 and parts[:3] == ["", "v1", "appAssetLibraryImages"]:
            return self.advance(parts[3])
        if len(parts) == 4 and parts[:3] == ["", "v1", "appAssetLibraryPlacements"]:
            return self.advance_slot(parts[3])
        raise AssertionError(f"unbekannter Pfad {path}")

    def visible(self, loc, group):
        return [slot for slot in self.slots if slot["loc"] == loc and slot["group"] == group and not slot.get("lost")]

    def names(self, loc, group):
        return [self.images[slot["image"]]["referenceName"] for slot in self.visible(loc, group)]

    @staticmethod
    def public(slot):
        record = {"id": slot["id"], "placementType": SHOT, "placementGroup": slot["group"], "state": slot["state"]}
        if "stateDetails" in slot:
            record["stateDetails"] = slot["stateDetails"]
        return record

    def advance_slot(self, slot_id):
        slot = next(slot for slot in self.slots if slot["id"] == slot_id)
        if slot["state"] == "ASSET_PROCESSING":
            self.polls[slot_id] = self.polls.get(slot_id, 0) + 1
            if self.polls[slot_id] >= self.processing:
                if self.images[slot["image"]]["referenceName"] in self.placement_fail:
                    slot["state"], slot["stateDetails"] = "FAILED", "Platzierung abgelehnt"
                else:
                    slot["state"] = "ACTIVE"
        return self.public(slot)

    def place(self, attributes, relationships):
        assert set(attributes) == {"placementType", "placementGroup"}, attributes
        assert attributes["placementType"] == SHOT, attributes
        assert set(relationships) == {"image", "appStoreVersionLocalization"}, relationships
        image, loc = relationships["image"]["data"], relationships["appStoreVersionLocalization"]["data"]
        assert image["type"] == "appAssetLibraryImages" and image["id"] in self.images, image
        assert loc["type"] == "appStoreVersionLocalizations", loc
        self.next_id += 1
        slot = {"id": f"P{self.next_id}", "image": image["id"], "loc": loc["id"], "group": attributes["placementGroup"],
                "state": "ASSET_PROCESSING", "lost": self.images[image["id"]]["referenceName"] in self.lose}
        if self.reverse_new:
            self.slots.insert(0, slot)
        else:
            self.slots.append(slot)
        return self.public(slot)

    def order(self, attributes, relationships):
        assert set(attributes) == {"placementGroup"}, attributes
        assert set(relationships) == {"orderedPlacements", "appStoreVersionLocalization"}, relationships
        loc = relationships["appStoreVersionLocalization"]["data"]
        assert loc["type"] == "appStoreVersionLocalizations", loc
        ordered = relationships["orderedPlacements"]["data"]
        assert all(item["type"] == "appAssetLibraryPlacements" for item in ordered), ordered
        ids = [item["id"] for item in ordered]
        group = self.visible(loc["id"], attributes["placementGroup"])
        assert set(ids) <= {slot["id"] for slot in group}, ids
        if not self.ignore_ordering:
            rest = [slot for slot in self.slots if slot["id"] not in ids]
            self.slots = rest + [next(slot for slot in group if slot["id"] == i) for i in ids]
        return {"id": f"O{len(self.calls)}"}

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
        if path == PLACEMENTS:
            return self.place(attributes, relationships)
        if path == ORDERING:
            return self.order(attributes, relationships)
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

    def delete(self, path):
        self.calls.append(("DELETE", path))
        raise AssertionError("dieses Skript löscht nie")

    def writes(self):
        return [call for call in self.calls if call[0] != "GET"]

    def posts(self):
        return [call for call in self.calls if call[0] == "POST" and call[1] == "/v1/appAssetLibraryImages"]

    def placement_posts(self):
        return [call for call in self.calls if call[0] == "POST" and call[1] == PLACEMENTS]

    def ordering_posts(self):
        return [call for call in self.calls if call[0] == "POST" and call[1] == ORDERING]


class NeedsModule(unittest.TestCase):
    """Legt ein Bildverzeichnis wie `docs/store/screenshots/` an: das echte en-Manifest, Dateien mit echtem PNG-Kopf."""

    def setUp(self):
        if si is None:
            self.fail("scripts/asc_store_images.py fehlt")
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        self.manifest = json.loads((ROOT / "docs/store/screenshots/en/manifest.json").read_text())
        self.write_tree(self.manifest)

    def write_tree(self, manifest, skip=(), sizes=None):
        base = self.root / "en"
        if base.exists():
            shutil.rmtree(base)
        base.mkdir(parents=True)
        (base / "manifest.json").write_text(json.dumps(manifest))
        for device in manifest["geraete"]:
            folder = base / device["ordner"]
            folder.mkdir()
            width, height = (sizes or {}).get(device["geraet"], map(int, device["pixel"].split("x")))
            for name in device["dateien"]:
                if f"{device['geraet']}/{name}" not in skip:
                    (folder / name).write_bytes(png(width, height))

    def localizations(self, locales=("de-DE", "en-US")):
        def lookup(version_id):
            self.asked.append(version_id)
            return {locale: {"id": f"L-{locale}", "attributes": {"locale": locale}} for locale in locales}
        self.asked = []
        return lookup

    def run_upload(self, client, versions=VERSIONS, locales=("de-DE", "en-US")):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            state = si.upload(client, APP, "en", versions, self.localizations(locales), sleep=lambda seconds: None,
                              root=self.root)
        return state, out.getvalue()

    def run_lesen(self, client, versions=VERSIONS):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            si.lesen(client, APP, "en", versions, self.localizations(), root=self.root)
        return out.getvalue()

    def run_place(self, client, versions=VERSIONS, locales=("de-DE", "en-US")):
        out, sleeps = io.StringIO(), []
        with contextlib.redirect_stdout(out):
            si.platzieren(client, APP, "en", versions, self.localizations(locales), sleep=sleeps.append, root=self.root)
        return out.getvalue(), sleeps


def ready_library(names=EN_NAMES):
    return [{"id": f"R{i}", "referenceName": name, "state": "PREPARE_FOR_SUBMISSION"} for i, name in enumerate(names)]


def german_page():
    """Die de-DE-Seite wie in der Store-Probe 42519049719: 5 iPhone, 5 iPad, 2 Watch, alle ACTIVE."""
    images, slots = [], []
    for group, count in DE_COUNTS.items():
        for n in range(count):
            image_id = f"G-{group}-{n}"
            images.append({"id": image_id, "referenceName": f"de-{group.lower()}-{n}", "state": "PREPARE_FOR_SUBMISSION"})
            slots.append({"id": f"D-{group}-{n}", "image": image_id, "loc": LOC_DE, "group": group, "state": "ACTIVE"})
    return images, slots


def en_slots(names, prefix="E"):
    """Vorhandene en-US-Platzierungen der genannten Plan-Bilder (Kennungen aus `ready_library`), Zustand ACTIVE."""
    group_of = {name: group for group, members in EN_GROUPS.items() for name in members}
    return [{"id": f"{prefix}{i}", "image": f"R{EN_NAMES.index(name)}", "loc": LOC_EN, "group": group_of[name],
             "state": "ACTIVE"} for i, name in enumerate(names)]


def place_client(library=None, en=(), **kwargs):
    """Bibliothek mit den 12 bereiten en-Bildern und der de-DE-Seite; `en` = schon vorhandene en-US-Platzierungen."""
    german_images, german_slots = german_page()
    images = (ready_library() if library is None else library) + german_images
    return FakeClient(images=images, slots=german_slots + list(en), **kwargs)


class PlanTests(NeedsModule):
    def test_plan_names_and_groups(self):
        entries = si.plan("en")
        self.assertEqual([e["reference"] for e in entries], EN_NAMES)
        groups = {"iphone": IPHONE, "ipad": IPAD, "watch": WATCH}
        for entry in entries:
            device = entry["reference"].split("-")[1]
            self.assertEqual(entry["group"], groups[device], entry["reference"])
            path = Path(entry["path"]).resolve()
            self.assertEqual(path.parent.parent, (ROOT / "docs/store/screenshots/en").resolve())
            self.assertEqual(path.name, entry["reference"].split("-", 2)[2] + ".png")
            self.assertTrue(path.exists(), path)
        self.assertFalse([e for e in entries if "mac" in e["reference"]])
        self.assertEqual([(e["width"], e["height"]) for e in entries[:1] + entries[5:6] + entries[10:11]],
                         [(1206, 2622), (2064, 2752), (416, 496)])


class LesenTests(NeedsModule):
    def test_read_only_never_writes(self):
        images = [{"id": "H1", "referenceName": "hell-16x9", "state": "PREPARE_FOR_SUBMISSION"},
                  {"id": "R0", "referenceName": "en-iphone-01-start", "state": "AWAITING_UPLOAD"}]
        client = FakeClient(images=images, placements={"H1": [{"id": "P1"}]})
        text = self.run_lesen(client)
        self.assertEqual(client.writes(), [])
        self.assertTrue(all(call[0] == "GET" for call in client.calls))
        self.assertIn("1.0.1", text)
        self.assertIn("en-US", text)
        for group in (IPHONE, IPAD, WATCH):
            self.assertRegex(text, rf"{group}\b.*maxCount=10")
        self.assertRegex(text, r"hell-16x9.*PREPARE_FOR_SUBMISSION.*platzierungen=1")
        self.assertRegex(text, r"en-iphone-01-start.*vorhanden")
        self.assertRegex(text, r"en-watch-02-gespeichert.*fehlt")
        self.assertRegex(text, r"(?m)^::warning::.*Mac")


class UploadTests(NeedsModule):
    def test_upload_creates_all_and_never_places(self):
        client = FakeClient()
        state, out = self.run_upload(client)
        self.assertEqual(state, "bereit")
        self.assertEqual(sorted(call[2]["referenceName"] for call in client.posts()), sorted(EN_NAMES))
        for call in client.posts():
            self.assertEqual(call[2]["category"], CATEGORY)
            self.assertEqual(call[3], {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": LIBRARY}}})
            self.assertEqual(call[2]["fileName"], call[2]["referenceName"].split("-", 2)[2] + ".png")
            self.assertGreater(call[2]["fileSize"], 0)
        self.assertEqual(len([c for c in client.calls if c[0] == "PUT"]), len(EN_NAMES))
        patches = [c for c in client.calls if c[0] == "PATCH"]
        self.assertEqual(len(patches), len(EN_NAMES))
        self.assertTrue(all(c[2] == {"uploaded": True} for c in patches))
        self.assertTrue(all(item["state"] == "PREPARE_FOR_SUBMISSION" for item in client.images.values()))
        self.assertEqual({c[0] for c in client.writes()}, {"POST", "PUT", "PATCH"})
        paths = " ".join(str(c[1]) for c in client.calls)
        for forbidden in ("appAssetLibraryPlacements", "OrderingRequests", "Submission"):
            self.assertNotIn(forbidden, paths)
        source = Path(si.__file__).read_text()
        for forbidden in ("Submission", "DELETE", ".delete("):
            self.assertNotIn(forbidden, source)

    def test_second_run_creates_nothing(self):
        client = FakeClient()
        self.run_upload(client)
        before = len(client.writes())
        state, out = self.run_upload(client)
        self.assertEqual(state, "bereit")
        self.assertEqual(len(client.writes()), before)
        for name in EN_NAMES:
            self.assertIn(f"bild {name} schon vorhanden, übersprungen", out)

    def test_existing_names_of_other_language_are_untouched(self):
        others = [{"id": "D1", "referenceName": "01-start", "state": "PREPARE_FOR_SUBMISSION"},
                  {"id": "D2", "referenceName": "de-iphone-01-start", "state": "PREPARE_FOR_SUBMISSION"}]
        client = FakeClient(images=others)
        self.run_upload(client)
        self.assertEqual(client.images["D1"], others[0])
        self.assertEqual(client.images["D2"], others[1])
        touched = [c for c in client.writes() if c[0] == "PATCH" and c[1].rsplit("/", 1)[1] in ("D1", "D2")]
        self.assertEqual(touched, [])
        self.assertTrue(all(c[2]["referenceName"].startswith("en-") for c in client.posts()))
        self.assertEqual(len(client.posts()), len(EN_NAMES))


class AbortTests(NeedsModule):
    def assert_aborts(self, needle, client=None, **kwargs):
        client = client or FakeClient()
        with self.assertRaises(Fatal) as caught:
            self.run_upload(client, **kwargs)
        self.assertEqual(client.writes(), [], needle)
        self.assertIn(needle, str(caught.exception))

    def test_aborts_before_any_write(self):
        with self.subTest("keine bearbeitbare iOS-Version"):
            self.assert_aborts("IOS", versions=[IOS_OLD, MAC_OLD])
        with self.subTest("zwei bearbeitbare iOS-Versionen"):
            twin = {"id": "V102", "attributes": {**IOS["attributes"], "versionString": "1.0.2"}}
            self.assert_aborts("IOS", versions=[IOS, twin, MAC_OLD])
        with self.subTest("keine en-US-Lokalisierung"):
            self.assert_aborts("en-US", locales=("de-DE",))
        with self.subTest("Gruppe fehlt in den Referenzdaten"):
            self.assert_aborts(WATCH, client=FakeClient(ref=refdata(groups=(IPHONE, IPAD))))
        with self.subTest("mehr Bilder als maxCount"):
            self.assert_aborts(IPAD, client=FakeClient(ref=refdata(limits={IPHONE: 10, IPAD: 4, WATCH: 10})))
        with self.subTest("Bilddatei fehlt"):
            self.write_tree(self.manifest, skip=("ipad/03-neu.png",))
            self.assert_aborts("03-neu.png")
        with self.subTest("Pixelmaß weicht ab"):
            self.write_tree(self.manifest, sizes={"watch": (410, 502)})
            self.assert_aborts("410x502")


class MacTests(NeedsModule):
    def test_mac_without_editable_version_is_skipped_with_warning(self):
        client = FakeClient()
        state, out = self.run_upload(client)
        self.assertEqual(state, "bereit")
        warnings = [line for line in out.splitlines() if line.startswith("::warning::")]
        self.assertEqual(len(warnings), 1)
        self.assertIn("Mac", warnings[0])
        self.assertFalse([c for c in client.posts() if "mac" in c[2]["referenceName"]])
        self.assertEqual(self.asked, ["V101"])


class StateTests(NeedsModule):
    def test_failed_processing_is_an_error(self):
        client = FakeClient(fail=["en-ipad-04-detail"])
        with self.assertRaises(Fatal) as caught:
            self.run_upload(client)
        self.assertIn("Bild entspricht keiner Spec", str(caught.exception))
        self.assertIn("en-ipad-04-detail", str(caught.exception))

    def test_ready_check_requires_ready_and_allows_placement(self):
        images = ready_library()
        self.assertEqual(si.check_ready(FakeClient(images=images), LIBRARY, EN_NAMES), "bereit")
        placed = FakeClient(images=images, placements={"R7": [{"id": "P1"}]})
        self.assertEqual(si.check_ready(placed, LIBRARY, EN_NAMES), "bereit")
        waiting = copy.deepcopy(images)
        waiting[3]["state"] = "AWAITING_UPLOAD"
        with self.assertRaises(Fatal) as caught:
            si.check_ready(FakeClient(images=waiting), LIBRARY, EN_NAMES)
        self.assertIn(EN_NAMES[3], str(caught.exception))
        self.assertIn("AWAITING_UPLOAD", str(caught.exception))
        with self.assertRaises(Fatal) as caught:
            si.check_ready(FakeClient(images=images[:-1]), LIBRARY, EN_NAMES)
        self.assertIn(EN_NAMES[-1], str(caught.exception))

    def test_waiting_image_from_broken_run_fails_second_run(self):
        stuck = [{"id": "S1", "referenceName": "en-watch-01-jetzt", "state": "AWAITING_UPLOAD"}]
        client = FakeClient(images=stuck)
        with self.assertRaises(Fatal) as caught:
            self.run_upload(client)
        self.assertIn("en-watch-01-jetzt", str(caught.exception))
        self.assertNotIn("en-watch-01-jetzt", [c[2]["referenceName"] for c in client.posts()])


class MainTests(unittest.TestCase):
    def setUp(self):
        if si is None:
            self.fail("scripts/asc_store_images.py fehlt")

    def test_language_input_is_checked(self):
        for argv in (["asc_store_images.py", "hochladen", "fr"], ["asc_store_images.py", "lesen", "fr"],
                     ["asc_store_images.py", "platzieren", "fr"], ["asc_store_images.py", "ordnen", "en"],
                     ["asc_store_images.py", "lesen"]):
            with self.subTest(argv=argv), mock.patch.object(si, "read_config") as config, \
                    mock.patch.object(si, "find_app_id") as find, mock.patch.object(si, "Client") as client:
                err = io.StringIO()
                with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
                    code = si.main(argv)
                self.assertEqual(code, 2)
                self.assertTrue(err.getvalue().strip())
                config.assert_not_called()
                find.assert_not_called()
                client.assert_not_called()


class WorkflowFileTests(unittest.TestCase):
    def test_workflow_runs_tests_first_and_hides_the_key(self):
        path = ROOT / ".github/workflows/asc-store-images.yml"
        self.assertTrue(path.exists(), path)
        text = path.read_text()
        tests = text.find("python3 -m unittest scripts/test_asc_store_images.py")
        run = text.find("python3 scripts/asc_store_images.py")
        self.assertGreater(tests, -1)
        self.assertGreater(run, tests)
        self.assertIn("workflow_dispatch", text)
        self.assertIn("pull_request", text)
        self.assertIn("github.event_name == 'workflow_dispatch'", text)
        self.assertIn("umask 077", text)
        self.assertIn("trap", text)
        for line in text.splitlines():
            if "echo" in line or "cat " in line:
                self.assertNotIn("ASC_PRIVATE_KEY", line)


class PlaceTests(NeedsModule):
    """4c-2: Platzieren auf en-US, Ordnen nur bei Abweichung, Wiederholung ohne Doppelanlage."""

    def assert_manifest_order(self, client):
        for group, names in EN_GROUPS.items():
            self.assertEqual(client.names(LOC_EN, group), names, group)

    def test_place_creates_all_in_manifest_order(self):
        client = place_client()
        self.run_place(client)
        posts = client.placement_posts()
        self.assertEqual(len(posts), 12)
        by_id = {item["id"]: item["referenceName"] for item in client.images.values()}
        created = {}
        for _, _, attributes, relationships in posts:
            self.assertEqual(attributes["placementType"], SHOT)
            self.assertEqual(relationships["appStoreVersionLocalization"]["data"],
                             {"type": "appStoreVersionLocalizations", "id": LOC_EN})
            created.setdefault(attributes["placementGroup"], []).append(by_id[relationships["image"]["data"]["id"]])
        self.assertEqual(created, EN_GROUPS)
        self.assertEqual({group: len(names) for group, names in created.items()}, {IPHONE: 5, IPAD: 5, WATCH: 2})
        self.assert_manifest_order(client)

    def test_place_orders_only_on_difference(self):
        with self.subTest("Reihenfolge stimmt schon"):
            client = place_client()
            self.run_place(client)
            self.assertEqual(client.ordering_posts(), [])
        with self.subTest("Apple liefert die neuen Platzierungen umgekehrt"):
            client = place_client(reverse_new=True)
            self.run_place(client)
            orders = client.ordering_posts()
            self.assertEqual(sorted(call[2]["placementGroup"] for call in orders), sorted(EN_GROUPS))
            for _, _, attributes, relationships in orders:
                self.assertEqual(relationships["appStoreVersionLocalization"]["data"]["id"], LOC_EN)
                ids = [item["id"] for item in relationships["orderedPlacements"]["data"]]
                image_of = {slot["id"]: client.images[slot["image"]]["referenceName"] for slot in client.slots}
                self.assertEqual([image_of[i] for i in ids], EN_GROUPS[attributes["placementGroup"]])
            self.assert_manifest_order(client)

    def test_second_run_places_nothing(self):
        client = place_client()
        self.run_place(client)
        before = len(client.writes())
        out, _ = self.run_place(client)
        self.assertEqual(len(client.writes()), before)
        for name in EN_NAMES:
            self.assertIn(f"platzierung {name} schon platziert, übersprungen", out)
        self.assert_manifest_order(client)

    def test_resume_after_partial_run_places_only_missing(self):
        client = place_client(en=en_slots(EN_NAMES[:3]))
        self.run_place(client)
        placed = [client.images[call[3]["image"]["data"]["id"]]["referenceName"] for call in client.placement_posts()]
        self.assertEqual(sorted(placed), sorted(EN_NAMES[3:]))
        self.assert_manifest_order(client)
        for group in EN_GROUPS:
            names = client.names(LOC_EN, group)
            self.assertEqual(len(names), len(set(names)), group)


class PlaceGuardTests(NeedsModule):
    """4c-2: alles, was das Platzieren verhindert, greift vor dem ersten Schreiben; de-DE wird nie beschrieben."""

    def assert_aborts(self, needles, client=None, **kwargs):
        client = client or place_client()
        with self.assertRaises(Fatal) as caught:
            self.run_place(client, **kwargs)
        self.assertEqual(client.writes(), [], needles)
        for needle in needles:
            self.assertIn(needle, str(caught.exception))

    def test_foreign_placement_aborts_without_write(self):
        foreign = {"id": "X1", "referenceName": "fremd-von-hand", "state": "PREPARE_FOR_SUBMISSION"}
        slot = {"id": "XP", "image": "X1", "loc": LOC_EN, "group": IPAD, "state": "ACTIVE"}
        self.assert_aborts((IPAD, "fremd-von-hand"), client=place_client(library=ready_library() + [foreign], en=[slot]))

    def test_duplicate_placement_of_same_image_aborts(self):
        twice = en_slots([EN_NAMES[1]], prefix="A") + en_slots([EN_NAMES[1]], prefix="B")
        self.assert_aborts((EN_NAMES[1],), client=place_client(en=twice))

    def test_preflight_aborts_before_any_write(self):
        with self.subTest("keine bearbeitbare iOS-Version"):
            self.assert_aborts(("IOS",), versions=[IOS_OLD, MAC_OLD])
        with self.subTest("zwei bearbeitbare iOS-Versionen"):
            twin = {"id": "V102", "attributes": {**IOS["attributes"], "versionString": "1.0.2"}}
            self.assert_aborts(("IOS",), versions=[IOS, twin, MAC_OLD])
        with self.subTest("keine en-US-Lokalisierung"):
            self.assert_aborts(("en-US",), locales=("de-DE",))
        with self.subTest("Plan-Bild fehlt in der Bibliothek"):
            self.assert_aborts((EN_NAMES[-1],), client=place_client(library=ready_library(EN_NAMES[:-1])))
        with self.subTest("Plan-Bild wartet noch auf den Upload"):
            waiting = ready_library()
            waiting[6]["state"] = "AWAITING_UPLOAD"
            self.assert_aborts((EN_NAMES[6], "AWAITING_UPLOAD"), client=place_client(library=waiting))
        with self.subTest("Gruppe fehlt in den Referenzdaten"):
            client = place_client()
            client.refdata = refdata(groups=(IPHONE, IPAD))
            self.assert_aborts((WATCH,), client=client)
        with self.subTest("mehr Bilder als maxCount"):
            client = place_client()
            client.refdata = refdata(limits={IPHONE: 4, IPAD: 10, WATCH: 10})
            self.assert_aborts((IPHONE,), client=client)

    def test_never_deletes_submits_or_writes_german(self):
        client = place_client(reverse_new=True)
        before = copy.deepcopy([slot for slot in client.slots if slot["loc"] == LOC_DE])
        self.run_place(client)
        self.run_place(client)
        self.assertTrue(client.placement_posts())
        self.assertTrue(client.ordering_posts())
        for call in client.calls:
            self.assertNotEqual(call[0], "DELETE")
            self.assertNotIn("submission", str(call[1]).lower())
        for call in client.writes():
            self.assertEqual(call[0], "POST", call[:2])
            body = json.dumps(call[3])
            self.assertIn(LOC_EN, body)
            self.assertNotIn(LOC_DE, body)
        self.assertEqual([slot for slot in client.slots if slot["loc"] == LOC_DE], before)
        for group, count in DE_COUNTS.items():
            self.assertEqual(len(client.names(LOC_DE, group)), count, group)

    def test_processing_waits_and_failure_is_an_error(self):
        client = place_client(processing=3)
        _, sleeps = self.run_place(client)
        self.assertTrue(sleeps)
        self.assertTrue(all(slot["state"] == "ACTIVE" for slot in client.slots))
        client = place_client(placement_fail=[EN_NAMES[8]])
        with self.assertRaises(Fatal) as caught:
            self.run_place(client)
        for needle in (EN_NAMES[8], "FAILED", "Platzierung abgelehnt"):
            self.assertIn(needle, str(caught.exception))

    def test_verification_detects_wrong_order_or_count(self):
        with self.subTest("Ordnen wirkt nicht"):
            client = place_client(reverse_new=True, ignore_ordering=True)
            with self.assertRaises(Fatal) as caught:
                self.run_place(client)
            self.assertRegex(str(caught.exception), f"{IPHONE}|{IPAD}|{WATCH}")
        with self.subTest("eine Platzierung fehlt nach dem Anlegen"):
            client = place_client(lose=[EN_NAMES[4]])
            with self.assertRaises(Fatal) as caught:
                self.run_place(client)
            text = str(caught.exception)
            self.assertIn(IPHONE, text)
            self.assertIn(EN_NAMES[4], text)
        with self.subTest("richtiger Stand"):
            out, _ = self.run_place(place_client())
            self.assertRegex(out, r"de-DE\D*5/5/2 unverändert")


class PlaceReadTests(NeedsModule):
    def test_lesen_shows_en_placements_and_never_writes(self):
        client = place_client(en=en_slots(EN_GROUPS[IPHONE]))
        text = self.run_lesen(client)
        self.assertTrue(all(call[0] == "GET" for call in client.calls))
        for position, name in enumerate(EN_GROUPS[IPHONE], start=1):
            self.assertRegex(text, rf"(?m)^platzierung {IPHONE} {position} {name} zustand=ACTIVE$")
        self.assertLess(text.find(EN_GROUPS[IPHONE][0] + " zustand"), text.find(EN_GROUPS[IPHONE][4] + " zustand"))
        for group in (IPAD, WATCH):
            self.assertRegex(text, rf"(?m)^platzierung {group} keine$")

    def test_upload_ready_check_allows_placement(self):
        client = place_client(en=en_slots(EN_NAMES))
        state, out = self.run_upload(client)
        self.assertEqual(state, "bereit")
        self.assertEqual(client.writes(), [])
        for name in EN_NAMES:
            self.assertIn(f"bild {name} schon vorhanden, übersprungen", out)


class PlaceMainTests(unittest.TestCase):
    def setUp(self):
        if si is None:
            self.fail("scripts/asc_store_images.py fehlt")

    def test_german_is_refused_without_any_call(self):
        with mock.patch.object(si, "read_config") as config, mock.patch.object(si, "find_app_id") as find, \
                mock.patch.object(si, "Client") as client, mock.patch.object(si, "app_versions") as versions:
            out = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                code = si.main(["asc_store_images.py", "platzieren", "de"])
        self.assertEqual(code, 1)
        self.assertRegex(out.getvalue(), r"(?m)^::error::.*de")
        config.assert_not_called()
        find.assert_not_called()
        client.assert_not_called()
        versions.assert_not_called()


class PlaceWorkflowTests(unittest.TestCase):
    def test_workflow_offers_platzieren_and_serializes(self):
        text = (ROOT / ".github/workflows/asc-store-images.yml").read_text()
        options = text[text.find("aktion:"):text.find("sprache:")]
        for option in ("- lesen", "- hochladen", "- platzieren"):
            self.assertIn(option, options)
        self.assertRegex(text, r"(?m)^concurrency:")
        self.assertIn("group: asc-store-images", text)
        self.assertRegex(text, r"cancel-in-progress:\s*false")
        self.assertIn('scripts/asc_store_images.py "$AKTION" "$SPRACHE"', text)
        self.assertLess(text.find("python3 -m unittest scripts/test_asc_store_images.py"),
                        text.find("python3 scripts/asc_store_images.py"))


if __name__ == "__main__":
    unittest.main()
