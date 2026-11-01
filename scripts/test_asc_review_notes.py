"""Tests für asc_review_notes.py und .github/workflows/asc-review-notes.yml (#788 Schnitt 1).

Aufruf: python3 scripts/test_asc_review_notes.py
Gegen einen lokalen Nachbau mit veränderlichem Zustand: er prüft nur die Form (welche Aufrufe, nichts vor der
Prüfung des Textes, kein Schreiben ohne Abweichung, nichts aus den Notizen oder Kontaktfeldern in der Ausgabe). Ob Apple
die Notizen im Zustand der Version annimmt, zeigt nur der echte Lauf `aktion=notizen`.
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

WANTED = "Loose Ends captures tasks.\n\nWunschtext-Geheim-788"
SECRET_NOTES = "Alter-Notiztext-Geheim-788"
CONTACT = {"contactFirstName": "Maxi", "contactLastName": "Beispiel", "contactPhone": "+49 170 0000000",
           "contactEmail": "kontakt@example.test"}
VERSION = {"id": "V1", "attributes": {"versionString": "1.0", "platform": "IOS", "appStoreState": "DEVELOPER_REJECTED"}}
ATTACHMENTS = [
    {"id": "A1", "attributes": {"fileName": "aufnahme.mov", "fileSize": 1234567,
                                "assetDeliveryState": {"state": "COMPLETE"}}},
    {"id": "A2", "attributes": {"fileName": "zweite.mov", "fileSize": 42, "assetDeliveryState": {"state": "FAILED"}}},
]


def detail(notes):
    return {"id": "R1", "attributes": {**CONTACT, "demoAccountRequired": False, "notes": notes}}


class FakeASC:
    """Nachbau mit Zustand: GET liest, PATCH schreibt `notes` in den Zustand; jede Anfrage wird gemerkt."""

    def __init__(self, versions=(VERSION,), notes=SECRET_NOTES, has_detail=True, attachments=(), patch_status=None):
        self.versions = [copy.deepcopy(item) for item in versions]
        self.detail = detail(notes) if has_detail else None
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
        if path.startswith("/v1/apps?"):
            return 200, {"data": [{"id": "APP1"}]}
        if path.startswith("/v1/apps/APP1/appStoreVersions"):
            return 200, {"data": self.versions}
        if path.startswith("/v1/appStoreVersions/V1/appStoreReviewDetail"):
            return (200, {"data": self.detail}) if self.detail else (404, {"errors": [{"status": "404"}]})
        if path.startswith("/v1/appStoreReviewDetails/R1/appStoreReviewAttachments"):
            return 200, {"data": self.attachments}
        return 404, {}

    def write(self, method, path, body):
        if method == "PATCH" and self.detail and path == "/v1/appStoreReviewDetails/R1":
            self.detail["attributes"].update(body["data"].get("attributes", {}))
            return 200, {"data": self.detail}
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def patches(self):
        return [body for method, path, body in self.writes() if method == "PATCH"]

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

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    # AC-5
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
        self.assert_failed(result)
        self.assertIn("<HIER_", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-2
    def test_limit_4000_bytes_passes(self):
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="a" * 4000)
        self.assert_ok(result)
        self.assertEqual(len(fake.patches()), 1, fake.writes())
        self.assertIn("notizen gesetzt bytes=4000", result.stdout)

    def test_4001_bytes_aborts_before_any_write(self):
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="a" * 4001)
        self.assert_failed(result)
        self.assertIn("4001", result.stdout)
        self.assertIn("4000", result.stdout)
        self.assertEqual(fake.writes(), [])
        self.assertFalse([p for _, p, _ in fake.requests if "appStoreReviewDetail" in p], fake.requests)

    def test_umlauts_count_two_bytes(self):
        fake = self.fake()
        self.assert_ok(self.run_notes(fake, "notizen", text="ä" * 2000))
        self.assertEqual(fake.patches()[0]["data"]["attributes"]["notes"], "ä" * 2000)
        fake = self.fake()
        result = self.run_notes(fake, "notizen", text="ä" * 2001)
        self.assert_failed(result)
        self.assertIn("4002", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-3
    def test_same_text_is_unchanged_no_patch(self):
        fake = self.fake(notes=WANTED)
        result = self.run_notes(fake, "notizen")
        self.assert_ok(result)
        self.assertIn("notizen unverändert bytes=", result.stdout)
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-4
    def test_different_text_exactly_one_patch_then_verified(self):
        for notes in (SECRET_NOTES, None, ""):
            fake = self.fake(notes=notes)
            result = self.run_notes(fake, "notizen")
            self.assert_ok(result)
            self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appStoreReviewDetails/R1")])
            data = fake.patches()[0]["data"]
            self.assertEqual(data["type"], "appStoreReviewDetails")
            self.assertEqual(data["id"], "R1")
            self.assertEqual(data["attributes"], {"notes": WANTED})
            self.assertIn(f"notizen gesetzt bytes={len(WANTED.encode())}", result.stdout)
            self.assertIn("gegenprobe gleich=ja", result.stdout)
            self.assertIn("zusammenfassung geschrieben=1", result.stdout)
            again = self.run_notes(fake, "notizen")
            self.assert_ok(again)
            self.assertIn("notizen unverändert", again.stdout)
            self.assertEqual(len(fake.patches()), 1)

    # AC-1
    def test_lesen_reports_states_and_never_writes(self):
        fake = self.fake(attachments=ATTACHMENTS)
        result = self.run_notes(fake, "lesen")
        self.assert_ok(result)
        self.assertIn("version 1.0 IOS appStoreState=DEVELOPER_REJECTED", result.stdout)
        self.assertIn(f"notizen gesetzt bytes={len(SECRET_NOTES.encode())}", result.stdout)
        self.assertIn("anhang name=aufnahme.mov groesse=1234567 assetDeliveryState=COMPLETE", result.stdout)
        self.assertIn("anhang name=zweite.mov groesse=42 assetDeliveryState=FAILED", result.stdout)
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)
        self.assertEqual(fake.writes(), [])
        versions = [p for _, p, _ in fake.requests if "/appStoreVersions" in p and p.startswith("/v1/apps/")]
        self.assertTrue(versions, fake.requests)
        self.assertIn("filter[platform]=IOS", versions[0])
        self.assertIn("filter[versionString]=1.0", versions[0])

    def test_lesen_without_attachments_and_with_empty_notes(self):
        for notes in (None, ""):
            fake = self.fake(notes=notes)
            result = self.run_notes(fake, "lesen")
            self.assert_ok(result)
            self.assertIn("notizen leer", result.stdout)
            self.assertIn("anhang keine", result.stdout)
            self.assertEqual(fake.writes(), [])

    # AC-6
    def test_output_never_contains_notes_text_or_contacts(self):
        secrets = (SECRET_NOTES, "Wunschtext-Geheim-788", *CONTACT.values(), "BEGIN", "PRIVATE KEY", "Bearer", "eyJ")
        runs = [(self.fake(attachments=ATTACHMENTS), "lesen", WANTED),
                (self.fake(), "notizen", WANTED),
                (self.fake(notes=WANTED), "notizen", WANTED),
                (self.fake(), "notizen", WANTED + "x" * 4000),
                (self.fake(patch_status=409), "notizen", WANTED),
                (self.fake(has_detail=False), "notizen", WANTED)]
        for fake, aktion, text in runs:
            result = self.run_notes(fake, aktion, text=text)
            output = result.stdout + result.stderr
            for secret in secrets:
                self.assertNotIn(secret, output, (aktion, secret))

    # AC-7
    def test_missing_version_has_clear_error(self):
        for aktion in ("lesen", "notizen"):
            fake = self.fake(versions=())
            result = self.run_notes(fake, aktion)
            self.assert_failed(result)
            self.assertIn("keine iOS-Version 1.0", result.stdout)
            self.assertEqual(fake.writes(), [])
        two = [VERSION, {**VERSION, "id": "V2"}]
        fake = self.fake(versions=two)
        result = self.run_notes(fake, "notizen")
        self.assert_failed(result)
        self.assertIn("2", result.stdout)
        self.assertEqual(fake.writes(), [])

    def test_missing_review_detail_has_clear_error_and_no_post(self):
        for aktion in ("lesen", "notizen"):
            fake = self.fake(has_detail=False)
            result = self.run_notes(fake, aktion)
            self.assert_failed(result)
            self.assertIn("keine App-Review-Informationen", result.stdout)
            self.assertEqual(fake.writes(), [])

    def test_patch_refused_has_own_message(self):
        for status in (403, 409):
            fake = self.fake(patch_status=status)
            result = self.run_notes(fake, "notizen")
            self.assert_failed(result)
            self.assertIn("nicht zu", result.stdout)
            self.assertIn("DEVELOPER_REJECTED", result.stdout)
            self.assertEqual(len(fake.writes()), 1, fake.writes())

    def test_unknown_action_aborts_before_any_request(self):
        fake = self.fake()
        result = self.run_notes(fake, "einreichen")
        self.assert_failed(result)
        self.assertEqual(fake.requests, [])


class NotesFileTests(unittest.TestCase):
    # AC-10
    def test_notes_file_has_no_placeholder_and_fits(self):
        from asc_review_notes import extract_notes
        text = extract_notes((REPO / "docs" / "reference" / "app-review-notizen.md").read_text(encoding="utf-8"))
        self.assertNotIn("<HIER_", text)
        self.assertIn("attached to this submission", text)
        self.assertLessEqual(len(text.encode("utf-8")), 4000)


class WorkflowTests(unittest.TestCase):
    # AC-8
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
