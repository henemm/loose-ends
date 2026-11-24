"""Tests für asc_review_notes.py und .github/workflows/asc-review-notes.yml (#788 Schnitt 1, #625 S5d-1).

Aufruf: python3 scripts/test_asc_review_notes.py
Gegen einen lokalen Nachbau mit veränderlichem Zustand: er prüft nur die Form (welche Aufrufe, nichts vor der
Prüfung des Textes, kein Schreiben ohne Abweichung, nichts aus den Notizen oder Kontaktfeldern in der Ausgabe). Seit
#625 S5d-1 schreibt das Skript je Plattform in die eine bearbeitbare Version (iOS und Mac), nicht mehr fest in iOS 1.0.
Ob Apple die Notizen im Zustand der Version annimmt, zeigt nur der echte Lauf `aktion=notizen`.
"""
import copy
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from asc_wait_build import Fatal  # noqa: E402

SCRIPT = SCRIPTS / "asc_review_notes.py"
REPO = SCRIPTS.parent
WORKFLOW = REPO / ".github" / "workflows" / "asc-review-notes.yml"
NOTES_FILE = REPO / "docs" / "reference" / "app-review-notizen.md"

WANTED = "Loose Ends captures tasks.\n\nWunschtext-Geheim-788"
SECRET_NOTES = "Alter-Notiztext-Geheim-788"
CONTACT = {"contactFirstName": "Maxi", "contactLastName": "Beispiel", "contactPhone": "+49 170 0000000",
           "contactEmail": "kontakt@example.test"}
EDITABLE = "PREPARE_FOR_SUBMISSION"


def version(version_id, platform, state, number):
    return {"id": version_id, "type": "appStoreVersions",
            "attributes": {"versionString": number, "platform": platform, "appStoreState": state}}


IOS_LIVE = version("V0", "IOS", "READY_FOR_SALE", "1.0.1")
IOS_EDIT = version("V1", "IOS", EDITABLE, "1.0.2")
MAC_LIVE = version("V8", "MAC_OS", "READY_FOR_SALE", "1.0.1")
MAC_EDIT = version("V2", "MAC_OS", EDITABLE, "1.0.2")
BOTH = (IOS_LIVE, IOS_EDIT, MAC_LIVE, MAC_EDIT)
ATTACHMENTS = [
    {"id": "A1", "attributes": {"fileName": "aufnahme.mov", "fileSize": 1234567,
                                "assetDeliveryState": {"state": "COMPLETE"}}},
    {"id": "A2", "attributes": {"fileName": "zweite.mov", "fileSize": 42, "assetDeliveryState": {"state": "FAILED"}}},
]


def detail(detail_id, notes):
    return {"id": detail_id, "type": "appStoreReviewDetails",
            "attributes": {**CONTACT, "demoAccountRequired": False, "notes": notes}}


class FakeASC:
    """Nachbau mit Zustand: Versionen, je Version ein Review-Detail (`R` + Versions-ID); GET liest, PATCH schreibt
    `notes`. `details` überschreibt je Version: None = 404, "null" = `data: null`."""

    def __init__(self, versions=BOTH, notes=SECRET_NOTES, details=None, attachments=(), patch_status=None):
        self.versions = [copy.deepcopy(item) for item in versions]
        self.details = {item["id"]: detail(f"R{item['id']}", notes) for item in self.versions}
        self.details.update(details or {})
        self.attachments = [copy.deepcopy(item) for item in attachments]
        self.patch_status = patch_status
        self.requests = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = json.dumps(body if body is not None else {}).encode()
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
                if fake.patch_status:
                    return self.reply(fake.patch_status, {"errors": [{"status": str(fake.patch_status)}]})
                return self.reply(*fake.write(self.command, self.path, body))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def read(self, path):
        url = path.split("?")[0]
        if url == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if url == "/v1/apps/APP1/appStoreVersions":
            return 200, {"data": self.versions}
        for version_id, found in self.details.items():
            if url == f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail":
                if found is None:
                    return 404, {"errors": [{"status": "404"}]}
                return 200, {"data": None if found == "null" else found}
            if isinstance(found, dict) and url == f"/v1/appStoreReviewDetails/{found['id']}/appStoreReviewAttachments":
                return 200, {"data": self.attachments}
        return 404, {}

    def write(self, method, path, body):
        for found in self.details.values():
            if method == "PATCH" and isinstance(found, dict) and path == f"/v1/appStoreReviewDetails/{found['id']}":
                found["attributes"].update(body["data"].get("attributes", {}))
                return 200, {"data": found}
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def patches(self):
        return [(path, body) for method, path, body in self.writes() if method == "PATCH"]

    def close(self):
        self.server.shutdown()


class ReviewNotesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def fake(self, **kwargs):
        fake = FakeASC(**kwargs)
        self.addCleanup(fake.close)
        return fake

    def notes_file(self, text, name="notizen.md"):
        path = Path(self.tmp.name) / name
        path.write_text(f"# Kopf\n\nVorspann.\n\n```\n\n{text}\n\n```\n\nNachsatz.\n", encoding="utf-8")
        return path

    def run_notes(self, fake, aktion, text=WANTED):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", REVIEW_NOTES_FILE=str(self.notes_file(text)))
        return subprocess.run([sys.executable, str(SCRIPT), aktion], env=env, capture_output=True, text=True,
                              timeout=120)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_failed(self, result, *needles):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        for needle in needles:
            self.assertIn(needle, result.stdout)

    # AC-5 (#788)
    def test_extracts_first_code_block(self):
        from asc_review_notes import extract_notes
        text = "# Titel\n\nVorher.\n\n```\n\n\nErste Zeile\n\n  zweite Zeile\n\n\n```\n\nDazwischen.\n\n```\nZweiter\n```\n"
        self.assertEqual(extract_notes(text), "Erste Zeile\n\n  zweite Zeile")
        with self.assertRaises(Fatal):
            extract_notes("# Titel\n\nKein Codeblock hier.\n")
        with self.assertRaises(Fatal):
            extract_notes("```\n\n\n```\n")

    def test_placeholder_aborts(self):
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="Video: <HIER_VIDEO_LINK>\n\nRest")
        self.assert_failed(result, "<HIER_")
        self.assertEqual(fake.writes(), [])

    # AC-2 (#788)
    def test_limit_4000_bytes_passes(self):
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="a" * 4000)
        self.assert_ok(result)
        self.assertEqual(len(fake.patches()), 2, fake.writes())
        self.assertIn("IOS notizen gesetzt bytes=4000", result.stdout)
        self.assertIn("MAC_OS notizen gesetzt bytes=4000", result.stdout)

    def test_4001_bytes_aborts_before_any_write(self):
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="a" * 4001)
        self.assert_failed(result, "4001", "4000")
        self.assertEqual(fake.requests, [])

    def test_umlauts_count_two_bytes(self):
        fake = self.fake()
        self.assert_ok(self.run_notes(fake, "notizen", text="ä" * 2000))
        self.assertEqual(fake.patches()[0][1]["data"]["attributes"]["notes"], "ä" * 2000)
        fake = self.fake()
        self.assert_failed(self.run_notes(fake, "notizen", text="ä" * 2001), "4002")
        self.assertEqual(fake.writes(), [])

    # S5d-1 AC-11
    def test_notizen_writes_to_editable_version_of_each_platform(self):
        for notes in (SECRET_NOTES, None, ""):
            fake = self.fake(notes=notes)
            result = self.run_notes(fake, "notizen")
            self.assert_ok(result)
            self.assertEqual(sorted(path for path, _ in fake.patches()),
                             ["/v1/appStoreReviewDetails/RV1", "/v1/appStoreReviewDetails/RV2"])
            for path, body in fake.patches():
                data = body["data"]
                self.assertEqual(data["type"], "appStoreReviewDetails")
                self.assertEqual(path, f"/v1/appStoreReviewDetails/{data['id']}")
                self.assertEqual(data["attributes"], {"notes": WANTED})
            for platform in ("IOS", "MAC_OS"):
                self.assertIn(f"{platform} notizen gesetzt bytes={len(WANTED.encode())}", result.stdout)
                self.assertIn(f"{platform} gegenprobe gleich=ja", result.stdout)
            self.assertIn("zusammenfassung geschrieben=2", result.stdout)
            self.assertEqual(fake.details["V0"]["attributes"]["notes"], notes)  # veröffentlichte Version unberührt
            versions = [p for _, p, _ in fake.requests if p.startswith("/v1/apps/APP1/appStoreVersions")]
            self.assertTrue(versions)
            for path in versions:
                self.assertNotIn("filter[versionString]", path)

    # S5d-1 AC-11
    def test_notizen_unchanged_when_equal(self):
        fake = self.fake(notes=WANTED)
        result = self.run_notes(fake, "notizen")
        self.assert_ok(result)
        self.assertIn("IOS notizen unverändert bytes=", result.stdout)
        self.assertIn("MAC_OS notizen unverändert bytes=", result.stdout)
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)
        self.assertEqual(fake.writes(), [])
        fake = self.fake(details={"V2": detail("RV2", WANTED)})
        result = self.run_notes(fake, "notizen")
        self.assert_ok(result)
        self.assertEqual([path for path, _ in fake.patches()], ["/v1/appStoreReviewDetails/RV1"])
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)

    # S5d-1 AC-11
    def test_notizen_patch_is_never_repeated(self):
        for status in (403, 409, 500):
            fake = self.fake(patch_status=status)
            result = self.run_notes(fake, "notizen")
            self.assert_failed(result, "IOS")
            self.assertEqual(len(fake.writes()), 1, (status, fake.writes()))
            if status in (403, 409):
                self.assertIn("nicht zu", result.stdout)
                self.assertIn(EDITABLE, result.stdout)

    # S5d-1 AC-11
    def test_lesen_never_writes(self):
        fake = self.fake(attachments=ATTACHMENTS)
        result = self.run_notes(fake, "lesen")
        self.assert_ok(result)
        self.assertIn("version IOS 1.0.2", result.stdout)
        self.assertIn("version MAC_OS 1.0.2", result.stdout)
        self.assertIn(f"IOS notizen gesetzt bytes={len(SECRET_NOTES.encode())}", result.stdout)
        self.assertIn("anhang name=aufnahme.mov groesse=1234567 assetDeliveryState=COMPLETE", result.stdout)
        self.assertIn("anhang name=zweite.mov groesse=42 assetDeliveryState=FAILED", result.stdout)
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)
        self.assertEqual(fake.writes(), [])
        for notes in (None, ""):
            fake = self.fake(notes=notes)
            result = self.run_notes(fake, "lesen")
            self.assert_ok(result)
            self.assertIn("notizen leer", result.stdout)
            self.assertIn("anhang keine", result.stdout)
            self.assertEqual(fake.writes(), [])
        fake = self.fake(versions=(IOS_LIVE, MAC_LIVE))
        result = self.run_notes(fake, "lesen")
        self.assert_ok(result)
        self.assertIn("keine bearbeitbare Version IOS", result.stdout)
        self.assertEqual(fake.writes(), [])

    # S5d-1 AC-12
    def test_notizen_aborts_without_editable_version(self):
        cases = (((IOS_LIVE, MAC_LIVE), "IOS"), ((IOS_LIVE, MAC_EDIT), "IOS"),
                 ((IOS_EDIT, MAC_LIVE), "MAC_OS"),
                 ((IOS_EDIT, version("V3", "IOS", EDITABLE, "1.0.3"), MAC_EDIT), "IOS"))
        for versions, platform in cases:
            fake = self.fake(versions=versions)
            result = self.run_notes(fake, "notizen")
            self.assert_failed(result, platform)
            self.assertEqual(fake.writes(), [], versions)

    # S5d-1 AC-12
    def test_notizen_aborts_without_review_detail_and_creates_nothing(self):
        for missing in (None, "null"):
            for version_id, platform in (("V1", "IOS"), ("V2", "MAC_OS")):
                fake = self.fake(details={version_id: missing})
                result = self.run_notes(fake, "notizen")
                self.assert_failed(result, platform, "keine App-Review-Informationen")
                self.assertEqual(fake.writes(), [], (missing, platform))

    # S5d-1 AC-12
    def test_notizen_aborts_before_writing_when_one_platform_fails(self):
        for kwargs in ({"versions": (IOS_EDIT, MAC_LIVE)}, {"details": {"V2": None}}):
            fake = self.fake(**kwargs)
            result = self.run_notes(fake, "notizen")
            self.assert_failed(result, "MAC_OS")
            self.assertEqual(fake.writes(), [], kwargs)
            self.assertEqual(fake.details["V1"]["attributes"]["notes"], SECRET_NOTES)

    # AC-6 (#788)
    def test_output_never_contains_notes_text_or_contacts(self):
        secrets = (SECRET_NOTES, "Wunschtext-Geheim-788", *CONTACT.values(), "BEGIN", "PRIVATE KEY", "Bearer", "eyJ")
        runs = [(self.fake(attachments=ATTACHMENTS), "lesen", WANTED),
                (self.fake(), "notizen", WANTED),
                (self.fake(notes=WANTED), "notizen", WANTED),
                (self.fake(), "notizen", WANTED + "x" * 4000),
                (self.fake(patch_status=409), "notizen", WANTED),
                (self.fake(details={"V1": None}), "notizen", WANTED)]
        for fake, aktion, text in runs:
            result = self.run_notes(fake, aktion, text=text)
            output = result.stdout + result.stderr
            for secret in secrets:
                self.assertNotIn(secret, output, (aktion, secret))

    def test_unknown_action_aborts_before_any_request(self):
        fake = self.fake()
        self.assert_failed(self.run_notes(fake, "einreichen"))
        self.assertEqual(fake.requests, [])


class NotesFileTests(unittest.TestCase):
    def notes(self):
        from asc_review_notes import extract_notes
        return extract_notes(NOTES_FILE.read_text(encoding="utf-8"))

    # AC-10 (#788)
    def test_notes_file_has_no_placeholder_and_fits(self):
        text = self.notes()
        self.assertNotIn("<HIER_", text)
        self.assertIn("attached to this submission", text)
        self.assertLessEqual(len(text.encode("utf-8")), 4000)

    # S5d-1 AC-13
    def test_real_notes_fit_the_limit(self):
        from asc_review_notes import MAX_BYTES, wanted_notes
        self.assertEqual(MAX_BYTES, 4000)
        os.environ.pop("REVIEW_NOTES_FILE", None)
        text = wanted_notes()
        self.assertEqual(text, self.notes())
        self.assertLessEqual(len(text.encode("utf-8")), 4000)
        self.assertNotIn("<HIER_", text)

    # S5d-1 AC-14
    def test_notes_have_no_false_statements(self):
        text = self.notes().lower()
        for false in ("no account registration", "login or account deletion", "no login", "no server of our own"):
            self.assertNotIn(false, text)

    # S5d-1 AC-14
    def test_notes_state_account_facts(self):
        text = self.notes().lower()
        for fact in ("Sign in with Apple", "5.1.1(v)", "Germany", "claude.ai", "Claude account",
                     "without an account", "no demo credentials"):
            self.assertIn(fact.lower(), text, fact)


class WorkflowTests(unittest.TestCase):
    # AC-8 (#788)
    def test_workflow_has_choice_unit_tests_and_secrets(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:", "pull_request"):
            self.assertNotIn(trigger, workflow)
        for needle in ("aktion:", "type: choice", "- lesen", "- notizen", "umask 077", "trap", "rm -f",
                       "timeout-minutes:", "contents: read"):
            self.assertIn(needle, workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        tests = workflow.index("python3 scripts/test_asc_review_notes.py")
        call = workflow.index("python3 scripts/asc_review_notes.py")
        self.assertLess(tests, call)
        # einzige Eingabe ist `aktion`: das Repo ist öffentlich, Eingaben stehen sichtbar in der Laufansicht
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))


if __name__ == "__main__":
    unittest.main()
