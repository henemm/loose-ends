"""Tests für asc_store_submit.py und .github/workflows/asc-store-submit.yml (#893 Schnitt A und B).

Aufruf: python3 scripts/test_asc_store_submit.py
Gegen den Nachbau aus test_asc_store_version.py, ergänzt um `GET /v1/reviewSubmissions` (Filter `app` und `platform`,
je Zeile `platform` und `state`). Geprüft wird die Vorprüfung beider Plattformen: Version, Bau, Texte, Bilder,
Review-Detail und Einreichungen, nur GET, ohne Kennungen, Rohantwort oder Wortlaut in der Ausgabe. Ob Apple die
Liste der Einreichungen so liefert, zeigt nur der echte Handlauf nach dem Merge (Definition of Done).
Schnitt B: der Nachbau legt Einreichungen an (`POST /v1/reviewSubmissions`), hängt Items an
(`POST /v1/reviewSubmissionItems`, gelesen über `GET …/items`, Beziehungsdaten nur mit `include` wie bei Apple) und
schickt ab (`PATCH …` mit `submitted=true`: Einreichung und Version `WAITING_FOR_REVIEW`, auf Wunsch verzögert
sichtbar). Fehler je Schreibschritt (Status, Fehlercode, Verbindungsabbruch) sind schaltbar.
"""
import copy
import os
import re
import subprocess
import sys
import tempfile
import unittest
import urllib.parse
from pathlib import Path

from test_asc_store_version import (EDITABLE, IOS_133, IOS_LIVE, IOS_NEW, MAC_133, MAC_LIVE, MAC_NEW, RAW_SECRET,
                                    FakeASC, build, loc, version)

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_store_submit.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "asc-store-submit.yml"
STORE_VERSION = SCRIPTS / "asc_store_version.py"
STORE_VERSION_TEST = SCRIPTS / "test_asc_store_version.py"

WORDING = "Wortlaut-im-Store-893"
USAGE = "::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>"
IDS = r"\b(APP1|V[1-5]|BI\d+|BM\d+|L[2-5]|SUB-\d+|RD-\w+|ITEM-\d+|EV\d+)\b"
WAITING = "WAITING_FOR_REVIEW"
READY = "READY_FOR_REVIEW"
PLATFORMS = ("IOS", "MAC_OS")
RELATIONS = ("appStoreVersion", "appEvent")
FULL = {"description": WORDING + "-d", "keywords": WORDING + "-k", "supportUrl": "https://example.org/" + WORDING,
        "whatsNew": WORDING + "-w", "promotionalText": WORDING + "-p"}


def texts(**changes):
    values = dict(FULL, **changes)
    return {field: value for field, value in values.items() if value is not None}


def submission(sub_id, platform, state):
    attrs = {"platform": platform}
    if state is not None:
        attrs["state"] = state
    return {"id": sub_id, "type": "reviewSubmissions", "attributes": attrs}


def released(item, release="AFTER_APPROVAL"):
    """Version mit Freigabeart; das Skript nennt sie, ändert sie nie."""
    return {**item, "attributes": {**item["attributes"], "releaseType": release}}


class Dropped(Exception):
    """Der Nachbau bricht die Verbindung ohne Antwort ab."""


class SubmitFakeASC(FakeASC):
    """Nachbau mit Einreichungen: `GET /v1/reviewSubmissions` filtert nach App und (abschaltbar) nach Plattform.

    Schnitt B: `items` je Einreichung als Liste von (Beziehung, Kennung); `write_fail` je Schritt
    (`POST reviewSubmissions`, `POST reviewSubmissionItems`, `PATCH reviewSubmissions`) → Status, (Status, Code) oder
    "drop"; `lag` = so oft zeigt das Lesen einer abgeschickten Einreichung bzw. Version noch den alten Zustand
    (None = nie den neuen)."""

    def __init__(self, *args, submissions=(), platform_filter=True, items=None, write_fail=None, lag=0, **kwargs):
        self.submissions = [copy.deepcopy(row) for row in submissions]
        self.platform_filter = platform_filter
        self.items = {key: list(value) for key, value in (items or {}).items()}
        self.write_fail = dict(write_fail or {})
        self.lag, self.hidden = lag, {}
        super().__init__(*args, **kwargs)
        self.server.handle_error = lambda *args: None

    def shown(self, row):
        """Ein Datensatz, wie Apple ihn gerade zeigt: nach dem Abschicken ggf. noch mit altem Zustand."""
        hidden = self.hidden.get(row["id"])
        if hidden is None:
            return row
        field, old, left = hidden
        if left is not None and left <= 0:
            del self.hidden[row["id"]]
            return row
        if left is not None:
            hidden[2] = left - 1
        return {**row, "attributes": {**row["attributes"], field: old}}

    def item_record(self, index, relation, target, include):
        relations = {}
        for name in RELATIONS:
            relations[name] = {"links": {"related": f"/v1/reviewSubmissionItems/ITEM-{index}/{name}"}}
            if name in include:
                kind = "appStoreVersions" if name == "appStoreVersion" else "appEvents"
                relations[name]["data"] = {"type": kind, "id": target} if name == relation else None
        return {"id": f"ITEM-{index}", "type": "reviewSubmissionItems", "attributes": {"state": READY},
                "relationships": relations}

    def read(self, path):
        url, _, query = path.partition("?")
        parts = url.strip("/").split("/")
        for suffix, status in self.get_fail.items():
            if url.endswith(suffix):
                return status, {"errors": [{"status": str(status), "detail": RAW_SECRET}]}
        if url == "/v1/apps/APP1/appStoreVersions":
            return 200, {"data": [self.shown(item) for item in self.versions]}
        if len(parts) == 3 and parts[1] == "appStoreVersions":
            found = [self.shown(item) for item in self.versions if item["id"] == parts[2]]
            return (200, {"data": found[0]}) if found else (404, {})
        if not url.startswith("/v1/reviewSubmissions"):
            return super().read(path)
        by_id = {row["id"]: row for row in self.submissions}
        if len(parts) in (3, 4) and parts[2] not in by_id:
            return 404, {}
        if len(parts) == 3:
            return 200, {"data": self.shown(by_id[parts[2]])}
        if len(parts) == 4 and parts[3] == "items":
            include = ",".join(urllib.parse.parse_qs(query).get("include", [])).split(",")
            return 200, {"data": [self.item_record(index, relation, target, include)
                                  for index, (relation, target) in enumerate(self.items.get(parts[2], []))]}
        params = urllib.parse.parse_qs(query)
        if params.get("filter[app]") != ["APP1"]:
            return 400, {"errors": [{"status": "400", "detail": RAW_SECRET}]}
        rows = self.submissions
        if self.platform_filter and "filter[platform]" in params:
            rows = [row for row in rows if row["attributes"]["platform"] in params["filter[platform]"]]
        return 200, {"data": [self.shown(row) for row in rows]}

    def write(self, method, path, body):
        parts = path.strip("/").split("/")
        step = f"{method} {parts[1] if len(parts) > 1 else ''}"
        failure = self.write_fail.get(step)
        if failure == "drop":
            raise Dropped(step)
        if failure is not None:
            status, code = failure if isinstance(failure, tuple) else (failure, None)
            return status, {"errors": [{"status": str(status), "title": WORDING, "detail": RAW_SECRET,
                                        **({"code": code} if code else {})}]}
        data = (body or {}).get("data") or {}
        if step == "POST reviewSubmissions" and len(parts) == 2:
            return self.create_submission(data)
        if step == "POST reviewSubmissionItems" and len(parts) == 2:
            return self.add_item(data)
        if step == "PATCH reviewSubmissions" and len(parts) == 3:
            return self.submit(parts[2], data)
        return super().write(method, path, body)

    def refuse(self, status, code):
        return status, {"errors": [{"status": str(status), "code": code, "detail": RAW_SECRET}]}

    def create_submission(self, data):
        platform = (data.get("attributes") or {}).get("platform")
        app = ((data.get("relationships") or {}).get("app") or {}).get("data")
        if data.get("type") != "reviewSubmissions" or platform not in PLATFORMS or app != {"type": "apps", "id": "APP1"}:
            return self.refuse(422, "ENTITY_ERROR")
        if any(row["attributes"]["platform"] == platform and row["attributes"].get("state") != "COMPLETE"
               for row in self.submissions):
            return self.refuse(409, "STATE_ERROR")
        row = submission(f"SUB-{100 + len(self.submissions)}", platform, READY)
        self.submissions.append(row)
        return 201, {"data": row}

    def add_item(self, data):
        relations = data.get("relationships") or {}
        sub = (relations.get("reviewSubmission") or {}).get("data") or {}
        target = (relations.get("appStoreVersion") or {}).get("data") or {}
        rows = [row for row in self.submissions if row["id"] == sub.get("id")]
        versions = [item for item in self.versions if item["id"] == target.get("id")]
        if (data.get("type") != "reviewSubmissionItems" or sub.get("type") != "reviewSubmissions"
                or target.get("type") != "appStoreVersions" or not rows or not versions):
            return self.refuse(422, "ENTITY_ERROR")
        if (rows[0]["attributes"].get("state") != READY
                or versions[0]["attributes"]["platform"] != rows[0]["attributes"]["platform"]
                or versions[0]["attributes"]["appStoreState"] != EDITABLE):
            return self.refuse(409, "STATE_ERROR")
        self.items.setdefault(rows[0]["id"], []).append(("appStoreVersion", target["id"]))
        return 201, {"data": self.item_record(len(self.items[rows[0]["id"]]) - 1, "appStoreVersion", target["id"],
                                              RELATIONS)}

    def submit(self, sub_id, data):
        rows = [row for row in self.submissions if row["id"] == sub_id]
        if (not rows or data.get("type") != "reviewSubmissions" or data.get("id") != sub_id
                or data.get("attributes") != {"submitted": True}):
            return self.refuse(422, "ENTITY_ERROR")
        if rows[0]["attributes"].get("state") != READY:
            return self.refuse(409, "STATE_ERROR")
        if not self.items.get(sub_id):
            return self.refuse(422, "ENTITY_UNPROCESSABLE")
        changed = [(rows[0], "state")] + [(item, "appStoreState") for item in self.versions
                                          if ("appStoreVersion", item["id"]) in self.items[sub_id]]
        for row, field in changed:
            self.hidden[row["id"]] = [field, row["attributes"].get(field), self.lag]
            row["attributes"][field] = WAITING
        return 200, {"data": self.shown(rows[0])}


def ready_state(**changes):
    """Beide Plattformen vollständig bereit: 1.0.1 bearbeitbar, Bau 133 gültig und zugeordnet, de-DE und en-US mit
    Texten, iOS mit Bildsätzen, Mac mit Platzierungen, Review-Detail für beide."""
    state = {
        "versions": (IOS_LIVE, IOS_NEW, MAC_LIVE, MAC_NEW),
        "builds": (IOS_133, MAC_133),
        "assigned": {"V2": "BI133", "V4": "BM133"},
        "localizations": {"V2": [loc("L2", "de-DE", **texts()), loc("L3", "en-US", **texts())],
                          "V4": [loc("L4", "de-DE", **texts()), loc("L5", "en-US", **texts())]},
        "sets": {"L2": [3], "L3": [2, 1]},
        "placements": {"L4": 4, "L5": 4},
        "review": {"V2", "V4"},
    }
    state.update(changes)
    return state


class StoreSubmitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def fake(self, **changes):
        state = ready_state(**{key: value for key, value in changes.items() if key in ready_state()})
        extra = {key: value for key, value in changes.items() if key not in state}
        fake = SubmitFakeASC(state.pop("versions"), state.pop("builds"), **state, **extra)
        self.addCleanup(fake.close)
        return fake

    def run_script(self, fake, *args):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2")
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True,
                              timeout=120)

    def pruefen(self, **changes):
        fake = self.fake(**changes)
        return fake, self.run_script(fake, "pruefen")

    def reasons(self, result, platform):
        prefix = f"{platform} nicht-bereit: "
        return [line[len(prefix):] for line in result.stdout.splitlines() if line.startswith(prefix)]

    def assert_ready(self, result, *platforms):
        for platform in platforms:
            self.assertIn(f"{platform} bereit", result.stdout.splitlines(), result.stdout + result.stderr)
            self.assertEqual(self.reasons(result, platform), [], result.stdout)

    def assert_reason(self, result, platform, *needles):
        """Eine Grund-Zeile der Plattform enthält alle Stücke; Ausgang 1 mit `::error::nicht bereit`."""
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::nicht bereit", result.stdout)
        found = [line for line in self.reasons(result, platform) if all(needle in line for needle in needles)]
        self.assertTrue(found, f"{platform} ohne Grund {needles}:\n{result.stdout}")

    def assert_clean(self, result):
        output = result.stdout + result.stderr
        for secret in (RAW_SECRET, WORDING, "PRIVATE KEY", "Bearer", "eyJ"):
            self.assertNotIn(secret, output)
        self.assertNotRegex(output, IDS)

    # AC-1
    def test_ready_on_both_platforms_exit_zero(self):
        fake, result = self.pruefen()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung bereit=ios,mac nicht-bereit=keine"),
                        result.stdout)
        self.assertNotIn("::error::", result.stdout)
        queries = [urllib.parse.parse_qs(path.partition("?")[2]) for _, path, _ in fake.requests
                   if path.startswith("/v1/reviewSubmissions?")]
        self.assertEqual(sorted(query["filter[platform]"][0] for query in queries), ["IOS", "MAC_OS"])
        for query in queries:
            self.assertEqual(query["filter[app]"], ["APP1"])
        self.assert_clean(result)

    # AC-2
    def test_version_rules(self):
        _, result = self.pruefen(versions=(IOS_LIVE, IOS_NEW, MAC_LIVE))
        self.assert_reason(result, "MAC_OS", "bearbeitbare Versionen=0", "READY_FOR_SALE")
        _, result = self.pruefen(versions=(IOS_LIVE, IOS_NEW, version("V5", "IOS", EDITABLE, "1.0.2"), MAC_NEW))
        self.assert_reason(result, "IOS", "bearbeitbare Versionen=2")
        _, result = self.pruefen(versions=(IOS_NEW, version("V4", "MAC_OS", EDITABLE, "1.0.2")),
                                 builds=(IOS_133, build("BM133", "MAC_OS", "133", pre="1.0.2")))
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "1.0.1", "1.0.2")

    # AC-3
    def test_build_rules(self):
        cases = ((dict(assigned={"V2": "BI133"}), "kein Bau"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", state="PROCESSING"))),
                  "processingState PROCESSING"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", expired=True))), "abgelaufen"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", pre="1.0"))), "vorabversion Soll 1.0.1 Ist 1.0"))
        for changes, needle in cases:
            with self.subTest(needle=needle):
                _, result = self.pruefen(**changes)
                self.assert_reason(result, "MAC_OS", needle)
                self.assert_ready(result, "IOS")

    # AC-4
    def test_text_rules(self):
        localized = ready_state()["localizations"]
        cases = (([loc("L2", "de-DE", **texts())], "en-US fehlt"),
                 ([loc("L2", "de-DE", **texts(whatsNew="")), localized["V2"][1]], "de-DE whatsNew leer"),
                 ([loc("L2", "de-DE", **texts(description=" \n\t ")), localized["V2"][1]], "de-DE description leer"),
                 ([localized["V2"][0], loc("L3", "en-US", **texts(keywords=None))], "en-US keywords leer"),
                 ([localized["V2"][0], loc("L3", "en-US", **texts(supportUrl=""))], "en-US supportUrl leer"))
        for rows, needle in cases:
            with self.subTest(needle=needle):
                _, result = self.pruefen(localizations={"V2": rows, "V4": localized["V4"]})
                self.assert_reason(result, "IOS", needle)
                self.assert_ready(result, "MAC_OS")
                self.assert_clean(result)
        _, result = self.pruefen(localizations={
            "V2": [loc("L2", "de-DE", **texts(promotionalText=None)), loc("L3", "en-US", **texts(promotionalText=""))],
            "V4": localized["V4"]})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")

    # AC-5
    def test_image_and_review_detail_rules(self):
        _, result = self.pruefen(sets={"L3": [2]}, placements={"L4": 4, "L5": 4})
        self.assert_reason(result, "IOS", "de-DE keine Bilder")
        self.assertFalse([line for line in self.reasons(result, "IOS") if "en-US" in line], result.stdout)
        self.assert_ready(result, "MAC_OS")
        _, result = self.pruefen(sets={"L2": [0], "L3": [1]})
        self.assert_reason(result, "IOS", "de-DE keine Bilder")
        _, result = self.pruefen(review={"V2"})
        self.assert_reason(result, "MAC_OS", "kein review-detail")
        self.assert_ready(result, "IOS")
        _, result = self.pruefen(sets={"L2": [1], "L3": [1], "L4": [2]}, placements={"L5": 1})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    # AC-6
    def test_submission_states(self):
        for state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"):
            with self.subTest(state=state):
                _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", state)])
                self.assert_reason(result, "IOS", "belegt", state)
                self.assert_ready(result, "MAC_OS")
        for state, word in (("SOMETHING_NEW", "SOMETHING_NEW"), (None, "unbekannter Zustand")):
            with self.subTest(state=state):
                _, result = self.pruefen(submissions=[submission("SUB-2", "MAC_OS", state)])
                self.assert_reason(result, "MAC_OS", "belegt, unbekannter Zustand", word)
        _, result = self.pruefen(submissions=[submission("SUB-3", "IOS", "COMPLETE"),
                                              submission("SUB-4", "MAC_OS", "COMPLETE")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        _, result = self.pruefen(submissions=[submission("SUB-5", "MAC_OS", "IN_REVIEW")], platform_filter=False)
        self.assert_reason(result, "MAC_OS", "belegt", "IN_REVIEW")
        self.assert_ready(result, "IOS")

    # AC-7
    def test_ready_for_review_is_reusable_but_two_are_not(self):
        _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", "READY_FOR_REVIEW")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")
        self.assertIn("IOS hinweis: einreichung READY_FOR_REVIEW wiederverwendbar", result.stdout)
        _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", "READY_FOR_REVIEW"),
                                              submission("SUB-2", "IOS", "READY_FOR_REVIEW")])
        self.assert_reason(result, "IOS", "READY_FOR_REVIEW", "mehrdeutig")
        self.assert_clean(result)

    # AC-8
    def test_both_platforms_fully_evaluated(self):
        _, result = self.pruefen(assigned={}, review=set(), submissions=[submission("SUB-1", "MAC_OS", "IN_REVIEW")])
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "kein Bau")
            self.assert_reason(result, platform, "kein review-detail")
        self.assert_reason(result, "MAC_OS", "belegt", "IN_REVIEW")
        self.assertIn("zusammenfassung bereit=keine nicht-bereit=ios,mac", result.stdout)
        self.assertIn("::error::nicht bereit: ios,mac", result.stdout)

    # AC-9
    def test_never_sends_non_get(self):
        for changes, code in (({}, 0), ({"assigned": {}}, 1)):
            plain = self.fake(**changes)
            refusing = self.fake(**changes, write_status=405)
            first, second = self.run_script(plain, "pruefen"), self.run_script(refusing, "pruefen")
            self.assertEqual(first.returncode, code, first.stdout + first.stderr)
            self.assertEqual(second.returncode, code, second.stdout + second.stderr)
            self.assertEqual(first.stdout, second.stdout)
            for fake in (plain, refusing):
                self.assertEqual(fake.writes(), [])
                self.assertTrue(fake.requests)
        source = SCRIPT.read_text()
        for needle in ("send_json", "DELETE"):
            self.assertNotIn(needle, source)

    # AC-10
    def test_output_has_no_ids_raw_answers_or_wording(self):
        _, result = self.pruefen(get_fail={"/V2/appStoreReviewDetail": 403, "/L3/appScreenshotSets": 500})
        self.assert_reason(result, "IOS", "nicht lesbar HTTP 403")
        self.assert_reason(result, "IOS", "nicht lesbar HTTP 500")
        self.assert_ready(result, "MAC_OS")
        self.assertIn("zusammenfassung bereit=mac nicht-bereit=ios", result.stdout)
        self.assert_clean(result)
        _, result = self.pruefen(get_fail={"/reviewSubmissions": 500})
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "nicht lesbar HTTP 500")
        self.assert_clean(result)

    # Schnitt A AC-11, Schnitt B AC-13
    def test_bad_usage_makes_no_call(self):
        for args in ((), ("unbekannt",), ("unbekannt", "1.0.1"), ("pruefen", "einreichen"), ("pruefen", "1.0.1")):
            with self.subTest(args=args):
                fake = self.fake()
                result = self.run_script(fake, *args)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(USAGE, result.stdout.splitlines())
                self.assertEqual(fake.requests, [])

    # AC-13
    def test_store_version_script_untouched(self):
        self.assertNotIn("ubmission", STORE_VERSION.read_text())
        self.assertIn("def test_never_deletes_submits_or_writes_texts", STORE_VERSION_TEST.read_text())
        result = subprocess.run([sys.executable, str(STORE_VERSION_TEST)], capture_output=True, text=True,
                                timeout=600, cwd=SCRIPTS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    # ---- Schnitt B: einreichen ----

    def submit_fake(self, **changes):
        changes.setdefault("versions", (IOS_LIVE, released(IOS_NEW), MAC_LIVE, released(MAC_NEW)))
        return self.fake(**changes)

    def einreichen(self, fake, *number):
        return self.run_script(fake, "einreichen", *(number or ("1.0.1",)))

    def steps(self, fake):
        """Schreibaufrufe als (Schritt, Ziel): anlegen → Plattform, item → Version, abschicken → Einreichung."""
        found = []
        for method, path, body in fake.writes():
            data = (body or {}).get("data") or {}
            if method == "POST" and path == "/v1/reviewSubmissions":
                found.append(("anlegen", data["attributes"]["platform"]))
            elif method == "POST" and path == "/v1/reviewSubmissionItems":
                found.append(("item", data["relationships"]["appStoreVersion"]["data"]["id"]))
            elif method == "PATCH" and path.startswith("/v1/reviewSubmissions/"):
                found.append(("abschicken", path.rsplit("/", 1)[1]))
            else:
                found.append((method, path))
        return found

    def sub_of(self, fake, platform):
        rows = [row["id"] for row in fake.submissions if row["attributes"]["platform"] == platform]
        self.assertEqual(len(rows), 1, fake.submissions)
        return rows[0]

    def assert_allowed_writes(self, fake):
        for method, path, body in fake.writes():
            data = (body or {}).get("data") or {}
            allowed = ((method, path) in (("POST", "/v1/reviewSubmissions"), ("POST", "/v1/reviewSubmissionItems"))
                       or (method == "PATCH" and re.fullmatch(r"/v1/reviewSubmissions/[^/]+", path)
                           and data.get("attributes") == {"submitted": True}))
            self.assertTrue(allowed, f"verbotener Schreibaufruf {method} {path}")

    def assert_submitted(self, result, *platforms):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for platform in platforms:
            self.assertIn(f"{platform} gegenprobe einreichung={WAITING} version={WAITING}", result.stdout)
        self.assertIn("zusammenfassung eingereicht=ios,mac", result.stdout)
        self.assertNotIn("::error::", result.stdout)

    def assert_refused(self, result, *needles):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        errors = [line for line in result.stdout.splitlines() if line.startswith("::error::")]
        self.assertTrue(errors, result.stdout)
        for needle in needles:
            self.assertIn(needle, result.stdout)

    # B AC-1
    def test_einreichen_success_both_platforms_ios_first(self):
        fake = self.submit_fake()
        result = self.einreichen(fake)
        self.assert_submitted(result, "IOS", "MAC_OS")
        ios, mac = self.sub_of(fake, "IOS"), self.sub_of(fake, "MAC_OS")
        self.assertEqual(self.steps(fake), [("anlegen", "IOS"), ("item", "V2"), ("abschicken", ios),
                                            ("anlegen", "MAC_OS"), ("item", "V4"), ("abschicken", mac)])
        items = [body["data"]["relationships"]["reviewSubmission"]["data"]["id"]
                 for method, path, body in fake.writes() if path == "/v1/reviewSubmissionItems"]
        self.assertEqual(items, [ios, mac])
        self.assertEqual(fake.items, {ios: [("appStoreVersion", "V2")], mac: [("appStoreVersion", "V4")]})
        for platform in ("IOS", "MAC_OS"):
            self.assertIn(f"{platform} bereit", result.stdout.splitlines())
        self.assert_clean(result)

    # B AC-2
    def test_confirmation_must_equal_version_number(self):
        for number in ((), ("1.0.2",), ("",), ("1.0",)):
            with self.subTest(number=number):
                fake = self.submit_fake()
                result = self.run_script(fake, "einreichen", *number)
                self.assert_refused(result)
                self.assertEqual(fake.writes(), [])

    # B AC-3
    def test_one_platform_not_ready_writes_nothing_on_both(self):
        for changes, platform, reason in ((dict(assigned={"V2": "BI133"}), "MAC_OS", "kein Bau"),
                                          (dict(review={"V4"}), "IOS", "kein review-detail")):
            with self.subTest(platform=platform):
                fake = self.submit_fake(**changes)
                result = self.einreichen(fake)
                self.assert_refused(result, f"{platform} nicht-bereit: {reason}")
                self.assertEqual(fake.writes(), [])

    # B AC-4
    def test_resume_ios_already_submitted_only_mac(self):
        fake = self.submit_fake(
            versions=(IOS_LIVE, released(version("V2", "IOS", WAITING, "1.0.1")), MAC_LIVE, released(MAC_NEW)),
            submissions=[submission("SUB-9", "IOS", WAITING)], items={"SUB-9": [("appStoreVersion", "V2")]})
        result = self.einreichen(fake)
        self.assert_submitted(result, "IOS", "MAC_OS")
        self.assertTrue([line for line in result.stdout.splitlines() if line.startswith("IOS eingereicht")],
                        result.stdout)
        mac = self.sub_of(fake, "MAC_OS")
        self.assertEqual(self.steps(fake), [("anlegen", "MAC_OS"), ("item", "V4"), ("abschicken", mac)])

    # B AC-5
    def test_reuses_single_ready_for_review_submission(self):
        for items, expected in (({}, [("item", "V2"), ("abschicken", "SUB-1")]),
                                ({"SUB-1": [("appStoreVersion", "V2")]}, [("abschicken", "SUB-1")])):
            with self.subTest(items=items):
                fake = self.submit_fake(submissions=[submission("SUB-1", "IOS", READY)], items=items)
                result = self.einreichen(fake)
                self.assert_submitted(result, "IOS", "MAC_OS")
                self.assertEqual(self.steps(fake)[:len(expected)], expected)
                self.assertNotIn(("anlegen", "IOS"), self.steps(fake))
                self.assertEqual(fake.items["SUB-1"], [("appStoreVersion", "V2")])

    # B AC-6
    def test_foreign_item_aborts_without_delete(self):
        for foreign in (("appEvent", "EV1"), ("appStoreVersion", "V1")):
            with self.subTest(foreign=foreign):
                fake = self.submit_fake(submissions=[submission("SUB-1", "IOS", READY)], items={"SUB-1": [foreign]})
                result = self.einreichen(fake)
                self.assert_refused(result, "fremd")
                self.assertEqual(fake.writes(), [])
                self.assertEqual(fake.items["SUB-1"], [foreign])
                self.assert_clean(result)

    # B AC-7
    def test_no_retry_on_5xx_or_network_error(self):
        for step in ("POST reviewSubmissions", "POST reviewSubmissionItems", "PATCH reviewSubmissions"):
            for failure in (500, 503, "drop"):
                with self.subTest(step=step, failure=failure):
                    fake = self.submit_fake(write_fail={step: failure})
                    result = self.einreichen(fake)
                    self.assert_refused(result)
                    method, _, name = step.partition(" ")
                    hits = [path for m, path, _ in fake.writes() if m == method and path.split("/")[2] == name]
                    self.assertEqual(len(hits), 1, fake.writes())
                    self.assertNotIn(("anlegen", "MAC_OS"), self.steps(fake))
                    self.assertNotIn(("item", "V4"), self.steps(fake))
                    self.assertTrue(self.steps(fake)[-1][0] in ("anlegen", "item", "abschicken"))
                    self.assert_clean(result)

    # B AC-8
    def test_409_and_422_clear_message_without_raw_answer(self):
        cases = (("POST reviewSubmissions", 409, "CONCURRENT_REVIEW_SUBMISSION_LIMIT_EXCEEDED"),
                 ("POST reviewSubmissionItems", 409, "STATE_ERROR.ENTITY_STATE_INVALID"),
                 ("PATCH reviewSubmissions", 422, "ENTITY_UNPROCESSABLE"))
        for step, status, code in cases:
            with self.subTest(step=step):
                fake = self.submit_fake(write_fail={step: (status, code)})
                result = self.einreichen(fake)
                method, _, name = step.partition(" ")
                self.assert_refused(result, code, str(status))
                line = [line for line in result.stdout.splitlines() if code in line][0]
                self.assertIn(method, line)
                self.assertIn(name, line)
                last = fake.writes()[-1]
                self.assertEqual((last[0], last[1].split("/")[2]), (method, name))
                self.assert_clean(result)

    # B AC-9
    def test_counter_check_failure_exit_one(self):
        fake = self.submit_fake(lag=None)
        result = self.einreichen(fake)
        self.assert_refused(result, "gegenprobe", READY, EDITABLE)
        self.assertNotIn("zusammenfassung eingereicht=ios,mac", result.stdout)
        self.assert_allowed_writes(fake)
        fake = self.submit_fake(lag=1)
        self.assert_submitted(self.einreichen(fake), "IOS", "MAC_OS")

    # B AC-10
    def test_einreichen_output_has_no_ids_raw_answers_or_wording(self):
        fake = self.submit_fake()
        result = self.einreichen(fake)
        self.assert_submitted(result, "IOS", "MAC_OS")
        self.assertIn("AFTER_APPROVAL", result.stdout)
        self.assert_clean(result)
        for failure in ((409, "STATE_ERROR"), "drop", 500):
            fake = self.submit_fake(write_fail={"PATCH reviewSubmissions": failure})
            self.assert_clean(self.einreichen(fake))
        fake = self.submit_fake(submissions=[submission("SUB-1", "IOS", READY)], items={"SUB-1": [("appEvent", "EV1")]})
        self.assert_clean(self.einreichen(fake))

    # B AC-11
    def test_never_deletes_or_touches_other_resources(self):
        scenarios = (dict(), dict(lag=1), dict(lag=None), dict(write_fail={"PATCH reviewSubmissions": 500}),
                     dict(submissions=[submission("SUB-1", "IOS", READY)]),
                     dict(submissions=[submission("SUB-1", "IOS", READY)], items={"SUB-1": [("appEvent", "EV1")]}),
                     dict(versions=(IOS_LIVE, released(version("V2", "IOS", WAITING, "1.0.1")), MAC_LIVE,
                                    released(MAC_NEW)),
                          submissions=[submission("SUB-9", "IOS", WAITING)],
                          items={"SUB-9": [("appStoreVersion", "V2")]}))
        for changes in scenarios:
            with self.subTest(changes=sorted(changes)):
                fake = self.submit_fake(**changes)
                self.einreichen(fake)
                self.assert_allowed_writes(fake)
                self.assertNotIn("DELETE", [method for method, _, _ in fake.requests])
        source = SCRIPT.read_text()
        self.assertNotIn("DELETE", source)
        self.assertNotIn("send_json", source)

    # B AC-12
    def test_second_run_writes_nothing(self):
        fake = self.submit_fake()
        self.assert_submitted(self.einreichen(fake), "IOS", "MAC_OS")
        before = len(fake.writes())
        result = self.einreichen(fake)
        self.assert_submitted(result, "IOS", "MAC_OS")
        self.assertEqual(len(fake.writes()), before)
        for platform in ("IOS", "MAC_OS"):
            self.assertTrue([line for line in result.stdout.splitlines() if line.startswith(f"{platform} eingereicht")],
                            result.stdout)

    # B AC-13
    def test_pruefen_unchanged(self):
        fake = self.submit_fake()
        result = self.run_script(fake, "pruefen")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung bereit=ios,mac nicht-bereit=keine"))
        self.assertEqual(fake.writes(), [])
        self.assert_submitted(self.einreichen(fake), "IOS", "MAC_OS")
        before = len(fake.writes())
        result = self.run_script(fake, "pruefen")
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "bearbeitbare Versionen=0")
            self.assert_reason(result, platform, "belegt", WAITING)
        self.assertEqual(len(fake.writes()), before)


class WorkflowTests(unittest.TestCase):
    # Schnitt A AC-12, Schnitt B AC-14
    def test_workflow_offers_einreichen_with_confirmation_and_hides_the_key(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        self.assertIn("pull_request:", workflow)
        options = workflow[workflow.index("options:"):workflow.index("default:")]
        self.assertEqual(re.findall(r"-\s+(\S+)", options), ["pruefen", "einreichen"])
        self.assertIn("bestaetigung:", workflow)
        self.assertIn("BESTAETIGUNG: ${{ inputs.bestaetigung }}", workflow)
        self.assertIn('"$BESTAETIGUNG"', workflow)
        key_write = workflow.index("secrets.ASC_PRIVATE_KEY }}\" >")
        self.assertLess(workflow.index('-z "$BESTAETIGUNG"'), key_write)
        gate = "if: github.event_name == 'workflow_dispatch'"
        self.assertEqual(workflow.count(gate), 1)
        self.assertLess(workflow.index(gate), workflow.index("python3 scripts/asc_store_submit.py"))
        self.assertGreater(workflow.index("secrets."), workflow.index(gate))
        for needle in ("aktion:", "type: choice", "default: pruefen", "concurrency:", "group: asc-store-submit\n",
                       "cancel-in-progress: false", "umask 077", "trap", "rm -f", "timeout-minutes:",
                       "contents: read"):
            self.assertIn(needle, workflow)
        for path in ("scripts/asc_store_submit.py", "scripts/test_asc_store_submit.py",
                     ".github/workflows/asc-store-submit.yml", "scripts/asc_store_version.py",
                     "scripts/asc_version_texts.py", "scripts/asc_beta_invite.py"):
            self.assertIn(f"- {path}", workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        run_steps = [line for line in workflow.splitlines() if "python3 scripts/" in line]
        self.assertIn("python3 scripts/test_asc_store_submit.py", run_steps[0])
        self.assertLess(workflow.index("python3 scripts/test_asc_store_submit.py"),
                        workflow.index("python3 scripts/asc_store_submit.py"))
        self.assertEqual(workflow.count("inputs."),
                         workflow.count("inputs.aktion") + workflow.count("inputs.bestaetigung"))
        for leak in ("cat \"$RUNNER_TEMP", "echo \"${{ secrets", "set -x"):
            self.assertNotIn(leak, workflow)


if __name__ == "__main__":
    unittest.main()
