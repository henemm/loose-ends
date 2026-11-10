"""Tests für asc_store_version.py und .github/workflows/asc-store-version.yml (#842 Schnitt 5a-1).

Aufruf: python3 scripts/test_asc_store_version.py
Gegen einen lokalen Nachbau mit Zustand. Er bildet nur Apples echte Pfade und Formen ab (Version: `platform`,
`versionString`, `appStoreState`; Bau: `version` = Buildnummer, `processingState`, `expired`, Vorabversion über
`/v1/builds/{id}/preReleaseVersion`; Zuordnung über `PATCH …/relationships/build`, 204) und prüft: welche Version
angelegt wird, welcher Bau zugeordnet wird, dass nichts vor der Plan-Prüfung geschrieben wird, nie umgehängt, nie
gelöscht, nie eingereicht. Ob Apple Anlegen und Zuordnung so annimmt, zeigt nur der echte Handlauf (AC-12).
"""
import copy
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_store_version.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "asc-store-version.yml"

RAW_SECRET = "Roh-Antwort-Geheim-842-5"
WORDING = "Wortlaut-der-Beschreibung-842"
EDITABLE = "PREPARE_FOR_SUBMISSION"
TEXT_FIELDS = ("description", "keywords", "promotionalText", "whatsNew", "supportUrl")


def version(version_id, platform, state, number):
    return {"id": version_id, "type": "appStoreVersions",
            "attributes": {"platform": platform, "versionString": number, "appStoreState": state}}


def build(build_id, platform, number, pre="1.0.1", state="VALID", expired=False):
    return {"id": build_id, "platform": platform, "number": number, "pre": pre, "state": state, "expired": expired}


IOS_LIVE = version("V1", "IOS", "READY_FOR_SALE", "1.0")
IOS_NEW = version("V2", "IOS", EDITABLE, "1.0.1")
MAC_LIVE = version("V3", "MAC_OS", "READY_FOR_SALE", "1.0")
MAC_NEW = version("V4", "MAC_OS", EDITABLE, "1.0.1")
IOS_133 = build("BI133", "IOS", "133")
MAC_133 = build("BM133", "MAC_OS", "133")


class FakeASC:
    """Nachbau mit Zustand: GET liest, POST legt eine Version an, PATCH ordnet einen Bau zu; jede Anfrage wird gemerkt."""

    def __init__(self, versions, builds=(), assigned=None, localizations=None, sets=None, placements=None,
                 review=(), fail_on=None, write_status=None, error_code=None, ignore_assign=False,
                 duplicate_create=False, loose_filters=False, get_fail=None, build_texts=None):
        self.versions = [copy.deepcopy(item) for item in versions]
        # „Was testen“ je Bau (#615 S4c-2a): Liste der Texte, None = Eintrag ohne Text; ohne Angabe ein Text ohne Marke
        self.build_texts = dict(build_texts or {})
        self.builds = [dict(item) for item in builds]
        self.assigned = dict(assigned or {})
        self.localizations = copy.deepcopy(localizations or {})
        self.sets = dict(sets or {})
        self.placements = dict(placements or {})
        self.review = set(review)
        self.fail_on, self.write_status, self.error_code = fail_on, write_status, error_code
        self.ignore_assign, self.duplicate_create, self.loose_filters = ignore_assign, duplicate_create, loose_filters
        self.get_fail = dict(get_fail or {})  # Pfadende → HTTP-Status für GET
        self.requests = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = b"" if status == 204 else json.dumps(body if body is not None else {}).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def handle_any(self):
                length = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(length)) if length else None
                fake.requests.append((self.command, self.path, body))
                if self.command == "GET":
                    return self.reply(*fake.read(self.path))
                if fake.write_status and fake.fail_on in (None, self.command):
                    return self.reply(fake.write_status,
                                      {"errors": [{"status": str(fake.write_status), "detail": RAW_SECRET,
                                                   **({"code": fake.error_code} if fake.error_code else {})}]})
                return self.reply(*fake.write(self.command, self.path, body))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def build_record(self, item):
        return {"id": item["id"], "type": "builds", "attributes": {
            "version": item["number"], "processingState": item["state"], "expired": item["expired"]}}

    def build_list(self, query):
        params = urllib.parse.parse_qs(query)
        found = [item for item in self.builds
                 if item["platform"] in params.get("filter[preReleaseVersion.platform]", [item["platform"]])
                 and item["pre"] in params.get("filter[preReleaseVersion.version]", [item["pre"]])]
        if not self.loose_filters:
            found = [item for item in found
                     if item["state"] in params.get("filter[processingState]", [item["state"]])
                     and str(item["expired"]).lower() in params.get("filter[expired]", [str(item["expired"]).lower()])]
        found.sort(key=lambda item: item["number"], reverse=True)  # Apples Textsortierung: "99" vor "133"
        return {"data": [self.build_record(item) for item in found]}

    def read(self, path):
        url, _, query = path.partition("?")
        for suffix, status in self.get_fail.items():
            if url.endswith(suffix):
                return status, {"errors": [{"status": str(status), "detail": RAW_SECRET}]}
        by_build = {item["id"]: item for item in self.builds}
        if url == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if url == "/v1/apps/APP1/appStoreVersions":
            return 200, {"data": self.versions}
        if url == "/v1/builds":
            return 200, self.build_list(query)
        parts = url.strip("/").split("/")
        if len(parts) == 4 and parts[1] == "builds" and parts[3] == "betaBuildLocalizations" and parts[2] in by_build:
            texts = self.build_texts.get(parts[2], ["Was testen: Erfassen"])
            return 200, {"data": [{"id": f"BL-{parts[2]}-{index}", "type": "betaBuildLocalizations",
                                   "attributes": {"locale": ("de-DE", "en-US", "fr-FR")[index % 3],
                                                  **({} if text is None else {"whatsNew": text})}}
                                  for index, text in enumerate(texts)]}
        if len(parts) == 4 and parts[1] == "builds" and parts[3] == "preReleaseVersion" and parts[2] in by_build:
            item = by_build[parts[2]]
            return 200, {"data": {"id": f"PRE-{item['id']}", "type": "preReleaseVersions",
                                  "attributes": {"version": item["pre"], "platform": item["platform"]}}}
        if len(parts) == 4 and parts[1] == "appStoreVersions":
            if parts[2] not in {item["id"] for item in self.versions}:
                return 404, {}
            if parts[3] == "build":
                chosen = by_build.get(self.assigned.get(parts[2]))
                return 200, {"data": self.build_record(chosen) if chosen else None}
            if parts[3] == "appStoreVersionLocalizations":
                return 200, {"data": self.localizations.get(parts[2], [])}
            if parts[3] == "appStoreReviewDetail":
                return 200, {"data": {"id": f"RD-{parts[2]}", "type": "appStoreReviewDetails",
                                      "attributes": {"notes": RAW_SECRET}} if parts[2] in self.review else None}
        if len(parts) == 4 and parts[1] == "appStoreVersionLocalizations":
            if parts[3] == "appScreenshotSets":
                return 200, {"data": [{"id": f"{parts[2]}-S{index}", "type": "appScreenshotSets"}
                                      for index in range(len(self.sets.get(parts[2], [])))]}
            if parts[3] == "placements":
                return 200, {"data": [{"id": f"{parts[2]}-P{index}", "type": "appAssetLibraryPlacements"}
                                      for index in range(self.placements.get(parts[2], 0))]}
        if len(parts) == 4 and parts[1] == "appScreenshotSets" and parts[3] == "appScreenshots":
            loc_id, _, index = parts[2].rpartition("-S")
            count = self.sets.get(loc_id, [])[int(index)]
            return 200, {"data": [{"id": f"{parts[2]}-I{n}", "type": "appScreenshots"} for n in range(count)]}
        return 404, {}

    def write(self, method, path, body):
        data = (body or {}).get("data") or {}
        if method == "POST" and path == "/v1/appStoreVersions":
            attrs = data.get("attributes", {})
            for suffix in ("", "-B")[:2 if self.duplicate_create else 1]:
                created = version(f"NEW{suffix}", attrs.get("platform"), EDITABLE, attrs.get("versionString"))
                self.versions.append(created)
            return 201, {"data": self.versions[-1]}
        parts = path.strip("/").split("/")
        if method == "PATCH" and len(parts) == 5 and parts[1] == "appStoreVersions" and parts[3:] == [
                "relationships", "build"]:
            if not self.ignore_assign:
                self.assigned[parts[2]] = data.get("id")
            return 204, None
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def close(self):
        self.server.shutdown()


def loc(loc_id, locale, **values):
    return {"id": loc_id, "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **values}}


class StoreVersionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def fake(self, versions=(IOS_LIVE, IOS_NEW, MAC_LIVE), builds=(IOS_133, MAC_133), **kwargs):
        fake = FakeASC(versions, builds, **kwargs)
        self.addCleanup(fake.close)
        return fake

    def run_script(self, fake, *args):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2")
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True,
                              timeout=120)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_failed(self, result, *needles):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        for needle in needles:
            self.assertIn(needle, result.stdout)

    def editable(self, fake, platform):
        return [item for item in fake.versions if item["attributes"]["platform"] == platform
                and item["attributes"]["appStoreState"] == EDITABLE]

    def patches(self, fake):
        return [(path.split("/")[3], body["data"]["id"]) for method, path, body in fake.writes() if method == "PATCH"]

    # AC-1
    def test_anlegen_creates_mac_version_with_ios_number(self):
        fake = self.fake()
        self.assert_ok(self.run_script(fake, "anlegen"))
        posts = [body for method, path, body in fake.writes() if method == "POST"]
        self.assertEqual(len(posts), 1, fake.writes())
        data = posts[0]["data"]
        self.assertEqual(data["type"], "appStoreVersions")
        self.assertEqual(data["attributes"], {"platform": "MAC_OS", "versionString": "1.0.1"})
        self.assertEqual(data["relationships"]["app"]["data"], {"type": "apps", "id": "APP1"})
        mine = self.editable(fake, "MAC_OS")
        self.assertEqual([item["attributes"]["versionString"] for item in mine], ["1.0.1"])

    # AC-2
    def test_anlegen_does_not_create_second_mac_version(self):
        fake = self.fake(versions=(IOS_LIVE, IOS_NEW, MAC_LIVE, MAC_NEW))
        for _ in range(2):
            result = self.run_script(fake, "anlegen")
            self.assert_ok(result)
            self.assertIn("version MAC_OS 1.0.1 schon vorhanden, übersprungen", result.stdout)
        self.assertEqual([m for m, _, _ in fake.writes() if m == "POST"], [])
        self.assertEqual(len(self.editable(fake, "MAC_OS")), 1)
        fresh = self.fake()
        for _ in range(2):
            self.assert_ok(self.run_script(fresh, "anlegen"))
        self.assertEqual([m for m, _, _ in fresh.writes() if m == "POST"], ["POST"])
        self.assertEqual(len(self.patches(fresh)), 2, fresh.writes())

    # AC-3
    def test_anlegen_fails_on_mac_version_mismatch(self):
        fake = self.fake(versions=(IOS_NEW, version("V4", "MAC_OS", EDITABLE, "1.0.2")))
        self.assert_failed(self.run_script(fake, "anlegen"), "1.0.1", "1.0.2")
        self.assertEqual(fake.writes(), [])

    # AC-3
    def test_anlegen_fails_without_or_with_several_ios_versions(self):
        for versions in ((IOS_LIVE, MAC_LIVE), (IOS_NEW, version("V5", "IOS", EDITABLE, "1.0.2"), MAC_LIVE)):
            fake = self.fake(versions=versions)
            self.assert_failed(self.run_script(fake, "anlegen"), "IOS")
            self.assertEqual(fake.writes(), [])

    # AC-4
    def test_build_is_picked_by_platform_version_and_valid(self):
        builds = (IOS_133, MAC_133, build("BM140", "MAC_OS", "140", pre="1.0"),
                  build("BI150", "IOS", "150", state="PROCESSING"), build("BM160", "MAC_OS", "160", state="FAILED"),
                  build("BI170", "IOS", "170", expired=True))
        fake = self.fake(builds=builds, loose_filters=True)
        self.assert_ok(self.run_script(fake, "anlegen"))
        self.assertEqual(sorted(self.patches(fake)), [("NEW", "BM133"), ("V2", "BI133")])
        queries = [urllib.parse.parse_qs(path.partition("?")[2]) for m, path, _ in fake.requests
                   if path.startswith("/v1/builds?")]
        self.assertEqual(sorted(q["filter[preReleaseVersion.platform]"][0] for q in queries), ["IOS", "MAC_OS"])
        for query in queries:
            self.assertEqual(query["filter[app]"], ["APP1"])
            self.assertEqual(query["filter[preReleaseVersion.version]"], ["1.0.1"])
            self.assertEqual(query["filter[processingState]"], ["VALID"])
            self.assertEqual(query["filter[expired]"], ["false"])

    # AC-4
    def test_build_highest_number_wins_and_is_logged(self):
        fake = self.fake(builds=(IOS_133, build("BM99", "MAC_OS", "99"), MAC_133))
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        self.assertIn(("NEW", "BM133"), self.patches(fake))
        self.assertIn("bau MAC_OS gewählt: 133 von 2 gültigen", result.stdout)

    # AC-5
    def test_existing_build_is_left_alone(self):
        fake = self.fake(versions=(IOS_NEW, MAC_NEW), builds=(build("BI130", "IOS", "130"), IOS_133, MAC_133),
                         assigned={"V2": "BI130"})
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        self.assertEqual(self.patches(fake), [("V4", "BM133")])
        self.assertIn("bau IOS schon zugeordnet: 130, unverändert", result.stdout)
        self.assertEqual(fake.assigned["V2"], "BI130")

    # AC-6
    def test_no_matching_build_is_fatal_and_writes_nothing(self):
        builds = (IOS_133, build("BM140", "MAC_OS", "140", pre="1.0"), build("BM133", "MAC_OS", "133", state="FAILED"))
        fake = self.fake(builds=builds)
        self.assert_failed(self.run_script(fake, "anlegen"), "kein gültiger Bau 1.0.1 für MAC_OS")
        self.assertEqual(fake.writes(), [])

    # AC-7
    def test_write_errors_are_clear_without_raw_answer(self):
        key_body = "".join(self.key.read_text().splitlines()[1:-1])
        cases = (("POST", 403, None, ("HTTP 403", "Schlüssel ohne Recht")),
                 ("PATCH", 409, "ENTITY_ERROR.RELATIONSHIP.INVALID",
                  ("HTTP 409", "Konflikt", "ENTITY_ERROR.RELATIONSHIP.INVALID", "gültig")))
        for method, status, code, needles in cases:
            fake = self.fake(fail_on=method, write_status=status, error_code=code)
            result = self.run_script(fake, "anlegen")
            self.assert_failed(result, *needles)
            output = result.stdout + result.stderr
            for secret in (RAW_SECRET, key_body, "PRIVATE KEY", "Bearer", "eyJ"):
                self.assertNotIn(secret, output)
            self.assertNotIn("zusammenfassung geschrieben", result.stdout)

    # AC-8
    def test_verification_fails_on_deviation(self):
        for kwargs in ({"ignore_assign": True}, {"duplicate_create": True}):
            fake = self.fake(**kwargs)
            self.assert_failed(self.run_script(fake, "anlegen"), "Gegenprobe", "MAC_OS")
            self.assertEqual([m for m, _, _ in fake.writes() if m == "POST"], ["POST"])
        fake = self.fake()
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        tail = result.stdout[result.stdout.rindex("gegenprobe"):]
        for needle in ("version MAC_OS 1.0.1 state=PREPARE_FOR_SUBMISSION", "bau IOS 1.0.1 (133)",
                       "bau MAC_OS 1.0.1 (133)"):
            self.assertIn(needle, tail)
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=3"), result.stdout)

    # AC-9
    def test_lesen_reports_state_and_never_writes(self):
        texts = {field: WORDING[: index + 5] for index, field in enumerate(TEXT_FIELDS)}
        fake = self.fake(versions=(IOS_LIVE, IOS_NEW, MAC_LIVE, MAC_NEW), assigned={"V2": "BI133"},
                         localizations={"V2": [loc("L2", "de-DE", **texts), loc("L3", "en-US")], "V4": []},
                         sets={"L2": [3, 2]}, placements={"L2": 4, "L3": 1}, review={"V2"})
        result = self.run_script(fake, "lesen")
        self.assert_ok(result)
        self.assertEqual([m for m, _, _ in fake.requests if m != "GET"], [])
        for needle in ("version IOS 1.0 state=READY_FOR_SALE", "version MAC_OS 1.0.1 state=PREPARE_FOR_SUBMISSION",
                       "bau IOS 1.0.1 (133) processingState=VALID", "bau MAC_OS kein Bau",
                       "bildsaetze=2 bilder=5 platzierungen=4", "bildsaetze=0 bilder=0 platzierungen=1",
                       "review-detail vorhanden", "review-detail keines"):
            self.assertIn(needle, result.stdout)
        for index, field in enumerate(TEXT_FIELDS):
            self.assertIn(f"{field} zeichen={index + 5}", result.stdout)
        self.assertIn("description zeichen=0", result.stdout)
        for secret in (WORDING[:5], RAW_SECRET):
            self.assertNotIn(secret, result.stdout + result.stderr)

    # AC-10
    def test_never_deletes_submits_or_writes_texts(self):
        runs = (self.fake(), self.fake(versions=(IOS_NEW, MAC_NEW)),
                self.fake(versions=(IOS_NEW, MAC_NEW), assigned={"V2": "BI133", "V4": "BM133"}))
        for fake in runs:
            for _ in range(2):
                self.assert_ok(self.run_script(fake, "anlegen"))
            for method, path, body in fake.writes():
                self.assertNotIn("ubmission", path)
                if method == "POST":
                    self.assertEqual(path, "/v1/appStoreVersions")
                    self.assertEqual(body["data"]["attributes"]["platform"], "MAC_OS")
                else:
                    self.assertEqual(method, "PATCH")
                    self.assertRegex(path, r"^/v1/appStoreVersions/[^/]+/relationships/build$")
        self.assertEqual(runs[2].writes(), [])

    # AC-10
    def test_bad_usage_makes_no_call(self):
        for args in ((), ("einreichen",), ("lesen", "anlegen")):
            fake = self.fake()
            self.assert_failed(self.run_script(fake, *args))
            self.assertEqual(fake.requests, [])

    # AC-5 (F003)
    def test_404_on_build_lookup_is_fatal_and_never_reassigns(self):
        for suffix in ("/V2/build", "/BI130/preReleaseVersion"):
            fake = self.fake(versions=(IOS_NEW, MAC_NEW), builds=(build("BI130", "IOS", "130"), IOS_133, MAC_133),
                             assigned={"V2": "BI130"}, get_fail={suffix: 404})
            result = self.run_script(fake, "anlegen")
            self.assert_failed(result, "HTTP 404")
            self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)
            self.assertEqual(fake.writes(), [], suffix)
            self.assertEqual(fake.assigned["V2"], "BI130")

    # AC-8/AC-9 (F001)
    def test_failed_count_query_is_reported_and_run_continues(self):
        for action, versions in (("lesen", (IOS_NEW, MAC_NEW)), ("anlegen", (IOS_LIVE, IOS_NEW, MAC_LIVE))):
            fake = self.fake(versions=versions, localizations={"V2": [loc("L2", "de-DE")]}, sets={"L2": [3]},
                             get_fail={"/placements": 400, "/L2/appScreenshotSets": 403})
            result = self.run_script(fake, action)
            self.assert_ok(result)
            self.assertIn("bildsaetze=fehler HTTP 403 bilder=fehler HTTP 403 platzierungen=fehler HTTP 400",
                          result.stdout)
            self.assertIn("zusammenfassung geschrieben=", result.stdout)
            self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)
        fake = self.fake(versions=(IOS_NEW, MAC_NEW), localizations={"V2": [loc("L2", "de-DE")]}, sets={"L2": [3, 2]},
                         get_fail={"/L2-S1/appScreenshots": 400})
        result = self.run_script(fake, "lesen")
        self.assert_ok(result)
        self.assertIn("bildsaetze=2 bilder=fehler HTTP 400 platzierungen=0", result.stdout)


# Schnitt 4c-2a (#615): ein Konto-Bau wird nie einer Store-Version zugeordnet, Unlesbares auch nicht (fail-closed)
sys.path.insert(0, str(SCRIPTS))
import asc_what_to_test  # noqa: E402

IOS_ONLY = (IOS_NEW, MAC_NEW)  # Mac hängt schon, geprüft wird nur die iOS-Wahl
MAC_ASSIGNED = {"V4": "BM133"}


def account_mark():
    value = getattr(asc_what_to_test, "ACCOUNT_BUILD_MARK", None)
    if not isinstance(value, str) or not value.strip():
        raise AssertionError("asc_what_to_test.ACCOUNT_BUILD_MARK fehlt")
    return value


def ios_builds(*numbers):
    return tuple(build(f"BI{number}", "IOS", str(number)) for number in numbers) + (MAC_133,)


class AccountBuildLockTests(unittest.TestCase):
    # nur die Hilfen, nicht die Fälle von StoreVersionTests (sonst liefen sie doppelt)
    setUp, fake, run_script = StoreVersionTests.setUp, StoreVersionTests.fake, StoreVersionTests.run_script
    assert_ok, assert_failed, patches = StoreVersionTests.assert_ok, StoreVersionTests.assert_failed, StoreVersionTests.patches

    def marked(self, text="Was testen: Erfassen"):
        return f"{text}\n{account_mark()}"

    # AC-9
    def test_pick_build_skips_account_builds(self):
        mark_one = {"BI134": ["frei", self.marked()], "BI135": [self.marked(), self.marked()]}
        fake = self.fake(versions=IOS_ONLY, builds=ios_builds(133, 134, 135, 136), assigned=MAC_ASSIGNED,
                         build_texts=mark_one)
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        self.assertEqual(self.patches(fake), [("V2", "BI136")])
        fake = self.fake(versions=IOS_ONLY, builds=ios_builds(133, 134, 135, 136), assigned=MAC_ASSIGNED,
                         build_texts={**mark_one, "BI136": [self.marked()]})
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        self.assertEqual(self.patches(fake), [("V2", "BI133")])
        for number in (134, 135, 136):
            self.assertIn(f"bau IOS {number} übersprungen: konto", result.stdout)
        self.assertNotIn(account_mark(), result.stdout + result.stderr)

    # AC-9
    def test_anlegen_never_assigns_account_build(self):
        builds = (IOS_133, build("BI140", "IOS", "140"), MAC_133, build("BM140", "MAC_OS", "140"))
        fake = self.fake(builds=builds, build_texts={"BI140": [self.marked()], "BM140": [self.marked()]})
        self.assert_ok(self.run_script(fake, "anlegen"))
        self.assertEqual(sorted(self.patches(fake)), [("NEW", "BM133"), ("V2", "BI133")])
        only_marked = self.fake(builds=(IOS_133, MAC_133), build_texts={"BM133": [self.marked()]})
        self.assert_failed(self.run_script(only_marked, "anlegen"), "kein gültiger Bau 1.0.1 für MAC_OS")
        self.assertEqual(only_marked.writes(), [])

    # AC-10
    def test_pick_build_fail_closed_on_unreadable(self):
        for status in (404, 500):
            fake = self.fake(versions=IOS_ONLY, builds=ios_builds(133, 136), assigned=MAC_ASSIGNED,
                             get_fail={"/BI136/betaBuildLocalizations": status})
            result = self.run_script(fake, "anlegen")
            self.assert_ok(result)
            self.assertEqual(self.patches(fake), [("V2", "BI133")], status)
            self.assertIn("bau IOS 136 übersprungen: texte nicht lesbar", result.stdout)
            self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)

    # AC-10
    def test_pick_build_fail_closed_on_empty(self):
        for texts in ([], [None], ["", "   "]):
            fake = self.fake(versions=IOS_ONLY, builds=ios_builds(133, 136), assigned=MAC_ASSIGNED,
                             build_texts={"BI136": texts})
            result = self.run_script(fake, "anlegen")
            self.assert_ok(result)
            self.assertEqual(self.patches(fake), [("V2", "BI133")], texts)
            self.assertIn("bau IOS 136 übersprungen: texte nicht lesbar", result.stdout)

    # AC-10
    def test_pick_build_nothing_left_writes_nothing(self):
        fake = self.fake(builds=ios_builds(133, 136),
                         get_fail={"/BI133/betaBuildLocalizations": 500}, build_texts={"BI136": []})
        result = self.run_script(fake, "anlegen")
        self.assert_failed(result, "kein gültiger Bau 1.0.1 für IOS", "2 übersprungen")
        self.assertEqual(fake.writes(), [])
        self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)

    # AC-11
    def test_pick_build_unchanged_without_marks(self):
        fake = self.fake(builds=(IOS_133, build("BM99", "MAC_OS", "99"), MAC_133))
        result = self.run_script(fake, "anlegen")
        self.assert_ok(result)
        self.assertEqual(sorted(self.patches(fake)), [("NEW", "BM133"), ("V2", "BI133")])
        self.assertIn("bau MAC_OS gewählt: 133 von 2 gültigen", result.stdout)
        self.assertNotIn("übersprungen:", result.stdout)
        read = {path for method, path, _ in fake.requests if method == "GET" and path.endswith("/betaBuildLocalizations")}
        self.assertTrue({"/v1/builds/BI133/betaBuildLocalizations", "/v1/builds/BM133/betaBuildLocalizations"} <= read,
                        read)


class WorkflowTests(unittest.TestCase):
    # AC-11
    def test_workflow_offers_both_actions_and_hides_the_key(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        self.assertIn("pull_request:", workflow)
        gate = "if: github.event_name == 'workflow_dispatch'"
        self.assertEqual(workflow.count(gate), 1)
        self.assertLess(workflow.index(gate), workflow.index("python3 scripts/asc_store_version.py"))
        self.assertGreater(workflow.index("secrets."), workflow.index(gate))
        for needle in ("aktion:", "type: choice", "- lesen", "- anlegen", "default: lesen", "concurrency:",
                       "group: asc-store-version", "cancel-in-progress: false", "umask 077", "trap", "rm -f",
                       "timeout-minutes:", "contents: read"):
            self.assertIn(needle, workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        self.assertLess(workflow.index("python3 scripts/test_asc_store_version.py"),
                        workflow.index("python3 scripts/asc_store_version.py"))
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))
        for leak in ("cat \"$RUNNER_TEMP", "echo \"${{ secrets", "set -x"):
            self.assertNotIn(leak, workflow)


if __name__ == "__main__":
    unittest.main()
