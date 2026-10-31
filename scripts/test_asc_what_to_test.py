"""Tests für asc_what_to_test.py und seine Schritte in testflight.yml (#347).

Aufruf: python3 scripts/test_asc_what_to_test.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; Apples echte Antworten zeigt nur der echte Lauf.
"""
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
from asc_what_to_test import split_sections  # noqa: E402

SCRIPT = SCRIPTS / "asc_what_to_test.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "testflight.yml"
BUILD = "42"
TEXT = "Siri auf Deutsch: „Neue Aufgabe in Loose Ends“ sagen."


class FakeASC:
    """Antwortet auf Apps, Builds und Sprachfassungen; merkt sich jede PATCH- und POST-Anfrage."""

    def __init__(self, localizations, patch_status=200):
        self.localizations, self.patch_status, self.writes = localizations, patch_status, []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = json.dumps(body or {}).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_GET(self):
                assert self.headers["Authorization"].startswith("Bearer ")
                if self.path.startswith("/v1/apps?"):
                    self.reply(200, {"data": [{"id": "APP1"}]})
                elif self.path.startswith("/v1/builds?"):
                    self.reply(200, {"data": [{"id": "B42", "attributes": {"version": BUILD}}]})
                elif self.path == "/v1/builds/B42/betaBuildLocalizations":
                    self.reply(200, {"data": fake.localizations})
                else:
                    self.reply(404)

            def write(self):
                length = int(self.headers["Content-Length"])
                fake.writes.append((self.command, self.path, json.loads(self.rfile.read(length))))
                self.reply(fake.patch_status if self.command == "PATCH" else 201)

            do_PATCH = write
            do_POST = write

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def close(self):
        self.server.shutdown()


class WhatToTestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, fake, text=TEXT):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key),
                   ASC_API_BASE=fake.base if fake else "http://127.0.0.1:9", ASC_POLL_SECONDS="0",
                   WHAT_TO_TEST=text)
        return subprocess.run([sys.executable, str(SCRIPT), BUILD], env=env, capture_output=True, text=True)

    def test_patches_every_localization_and_keeps_existing_german(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "en-US"}},
                        {"id": "L2", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([(m, p) for m, p, _ in fake.writes],
                         [("PATCH", "/v1/betaBuildLocalizations/L1"), ("PATCH", "/v1/betaBuildLocalizations/L2")])
        self.assertTrue(all(body["data"]["attributes"]["whatsNew"] == TEXT for _, _, body in fake.writes))

    def test_creates_the_localization_of_every_shipped_language_when_missing(self):
        fake = FakeASC([])
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({(m, p) for m, p, _ in fake.writes}, {("POST", "/v1/betaBuildLocalizations")})
        created = {body["data"]["attributes"]["locale"]: body["data"]["attributes"]["whatsNew"] for _, _, body in fake.writes}
        self.assertEqual(created, {"de-DE": TEXT, "en-US": TEXT})
        for _, _, body in fake.writes:
            self.assertEqual(body["data"]["relationships"]["build"]["data"], {"type": "builds", "id": "B42"})
        self.assertIn("whatToTest gesetzt für", result.stdout)

    def test_each_localization_gets_its_own_section(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "en-US"}},
                        {"id": "L2", "attributes": {"locale": "de-DE"}},
                        {"id": "L3", "attributes": {"locale": "fr-FR"}}])
        self.addCleanup(fake.close)
        result = self.run_script(fake, text="de: Deutscher Text\nen: English text")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        sent = {p.rsplit("/", 1)[1]: body["data"]["attributes"]["whatsNew"] for _, p, body in fake.writes}
        self.assertEqual(sent, {"L1": "English text", "L2": "Deutscher Text", "L3": "Deutscher Text"})

    def test_empty_text_fails_before_any_request(self):
        result = self.run_script(None, text="  ")
        self.assertEqual(result.returncode, 1)
        self.assertIn("WHAT_TO_TEST is empty", result.stdout)

    def test_too_long_text_fails(self):
        result = self.run_script(None, text="x" * 4001)
        self.assertEqual(result.returncode, 1)
        self.assertIn("at most 4000", result.stdout)

    def test_rejected_write_fails(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}], patch_status=409)
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 1)
        self.assertIn("HTTP 409", result.stdout)


class SectionTests(unittest.TestCase):
    def test_sections_split_by_language_marker(self):
        self.assertEqual(split_sections("de: A\nen: B"), {"de-DE": "A", "en-US": "B"})
        self.assertEqual(split_sections("de: A\nweiter\nen: B"), {"de-DE": "A\nweiter", "en-US": "B"})

    def test_text_without_marker_is_german(self):
        self.assertEqual(split_sections("A"), {"de-DE": "A"})
        self.assertEqual(split_sections("Hinweis: A"), {"de-DE": "Hinweis: A"})

    def test_missing_section_falls_back_to_german(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        tester = WhatToTestTests()
        tester.setUp()
        self.addCleanup(tester.tearDown)
        result = tester.run_script(fake, text="de: A")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        sent = {(m, body["data"]["attributes"].get("locale", p.rsplit("/", 1)[1])): body["data"]["attributes"]["whatsNew"]
                for m, p, body in fake.writes}
        self.assertEqual(sent, {("PATCH", "L1"): "A", ("POST", "en-US"): "A"})

    def test_unknown_language_code_fails(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            shutil.copytree(SCRIPTS.parent / "Shared/Language", Path(folder) / "Shared/Language")
            pack = Path(folder) / "Shared/Language/LanguagePack.swift"
            pack.write_text(pack.read_text(encoding="utf-8").replace("[.english, .german]", "[.english, .german, .test]"),
                            encoding="utf-8")
            (pack.parent / "TestPack.swift").write_text('extension LanguagePack {\n    static let test = LanguagePack(\n        code: "zz",\n')
            with self.assertRaises(Fatal) as raised:
                split_sections("de: A", folder)
            self.assertIn("zz", str(raised.exception))


class WorkflowTests(unittest.TestCase):
    def test_workflow_asks_for_the_text_and_writes_it_after_processing(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("what_to_test:", workflow)
        self.assertIn("WHAT_TO_TEST: ${{ inputs.what_to_test || github.event.head_commit.message }}", workflow)
        self.assertLess(workflow.index("scripts/asc_wait_build.py"), workflow.index("scripts/asc_what_to_test.py"))


if __name__ == "__main__":
    unittest.main()
