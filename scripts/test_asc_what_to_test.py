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

    def test_creates_german_localization_when_missing(self):
        fake = FakeASC([])
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        (method, path, body), = fake.writes
        self.assertEqual((method, path), ("POST", "/v1/betaBuildLocalizations"))
        self.assertEqual(body["data"]["attributes"], {"locale": "de-DE", "whatsNew": TEXT})
        self.assertEqual(body["data"]["relationships"]["build"]["data"], {"type": "builds", "id": "B42"})

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


class WorkflowTests(unittest.TestCase):
    def test_workflow_asks_for_the_text_and_writes_it_after_processing(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("what_to_test:", workflow)
        self.assertIn("WHAT_TO_TEST: ${{ inputs.what_to_test || github.event.head_commit.message }}", workflow)
        self.assertLess(workflow.index("scripts/asc_wait_build.py"), workflow.index("scripts/asc_what_to_test.py"))


if __name__ == "__main__":
    unittest.main()
