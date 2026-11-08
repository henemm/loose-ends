"""Tests für asc_store_images.py: Store-Bilder einer Sprache in Apples Asset-Bibliothek legen, nie platzieren (#842, 4c-1).

Die Attrappe liefert Apples dokumentierte Form (Datenmodell `AppAssetLibraryRefDatum`, gelesen 2026-11-08):
`features[].featureId` mit `placementPolicies[].placementType` und `groupLimits[]` aus `groupIds` und `maxCount`,
`placementTypes[]` mit `placementTypeId` und `acceptsAssetCategories`, `placementProfileGroups[]` mit
`placementProfileGroupId`. Die Gruppennamen sind die echten aus dem Lauf der Store-Probe 42515431363, nicht die veralteten
der Probe-Fixtures. Versionen kommen roh (id + attributes) wie aus `asc_version_texts.app_versions`, Lokalisierungen über
eine übergebene Funktion. Ob Apple die Bilder nimmt, zeigt nur der echte Lauf.

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

    def __init__(self, ref=None, images=(), placements=None, fail=()):
        self.refdata = ref or refdata()
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

    def delete(self, path):
        self.calls.append(("DELETE", path))
        raise AssertionError("dieses Skript löscht nie")

    def writes(self):
        return [call for call in self.calls if call[0] != "GET"]

    def posts(self):
        return [call for call in self.calls if call[0] == "POST"]


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


def ready_library(names=EN_NAMES):
    return [{"id": f"R{i}", "referenceName": name, "state": "PREPARE_FOR_SUBMISSION"} for i, name in enumerate(names)]


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
        self.assertEqual(len([c for c in client.calls if c[0] == "PUT"]), 11)
        patches = [c for c in client.calls if c[0] == "PATCH"]
        self.assertEqual(len(patches), 11)
        self.assertTrue(all(c[2] == {"uploaded": True} for c in patches))
        self.assertTrue(all(item["state"] == "PREPARE_FOR_SUBMISSION" for item in client.images.values()))
        self.assertEqual({c[0] for c in client.writes()}, {"POST", "PUT", "PATCH"})
        paths = " ".join(str(c[1]) for c in client.calls)
        for forbidden in ("appAssetLibraryPlacements", "OrderingRequests", "Submission"):
            self.assertNotIn(forbidden, paths)
        source = Path(si.__file__).read_text()
        for forbidden in ("appAssetLibraryPlacements", "OrderingRequests", "Submission", "DELETE", ".delete("):
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
        self.assertEqual(len(client.posts()), 11)


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

    def test_state_check_requires_ready_and_no_placement(self):
        images = ready_library()
        self.assertEqual(si.check_state(FakeClient(images=images), LIBRARY, EN_NAMES), "bereit")
        waiting = copy.deepcopy(images)
        waiting[3]["state"] = "AWAITING_UPLOAD"
        with self.assertRaises(Fatal) as caught:
            si.check_state(FakeClient(images=waiting), LIBRARY, EN_NAMES)
        self.assertIn(EN_NAMES[3], str(caught.exception))
        with self.assertRaises(Fatal) as caught:
            si.check_state(FakeClient(images=images, placements={"R7": [{"id": "P1"}]}), LIBRARY, EN_NAMES)
        self.assertIn(EN_NAMES[7], str(caught.exception))
        with self.assertRaises(Fatal):
            si.check_state(FakeClient(images=images[:-1]), LIBRARY, EN_NAMES)

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
                     ["asc_store_images.py", "platzieren", "en"], ["asc_store_images.py", "lesen"]):
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


if __name__ == "__main__":
    unittest.main()
