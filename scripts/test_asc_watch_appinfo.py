"""Tests für asc_watch_appinfo.py und .github/workflows/asc-watch-appinfo.yml (#846).

Aufruf: python3 scripts/test_asc_watch_appinfo.py
Gegen einen lokalen Nachbau von App Store Connect: geprüft werden die drei Lagen, das stille Verhalten bei 5xx,
das laute bei 401/403, die Ausgabe ohne Zugangsdaten und die Form des Workflows (als Text gelesen).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

SCRIPT = SCRIPTS / "asc_watch_appinfo.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "asc-watch-appinfo.yml"

RAW_SECRET = "Roh-Antwort-Geheim-846"
KEY_ID, ISSUER_ID = "SCHLUESSEL-KENNUNG-846", "AUSSTELLER-846"


def info(info_id, state):
    return {"id": info_id, "type": "appInfos", "attributes": {"state": state, "appStoreState": state}}


def version(version_id, platform, number, state):
    return {"id": version_id, "type": "appStoreVersions",
            "attributes": {"platform": platform, "versionString": number, "appStoreState": state}}


LOCKED = [info("I1", "READY_FOR_DISTRIBUTION"), info("I2", "IN_REVIEW")]
EDITABLE = [info("I1", "READY_FOR_DISTRIBUTION"), info("I2", "PREPARE_FOR_SUBMISSION")]
IOS_LIVE = version("V1", "IOS", "1.0", "READY_FOR_SALE")


def mac(state, number="1.0"):
    return version("V2", "MAC_OS", number, state)


class FakeASC:
    """Nachbau, der nur liest; `status` lässt jede Antwort mit diesem Code scheitern."""

    def __init__(self, infos, versions, status=None):
        self.infos, self.versions, self.status = infos, versions, status
        self.requests = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def handle_any(self):
                fake.requests.append((self.command, self.path))
                code, body = fake.answer(self.path)
                raw = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def answer(self, path):
        if self.status:
            return self.status, {"errors": [{"status": str(self.status), "detail": RAW_SECRET}]}
        url = path.split("?")[0]
        if url == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if url == "/v1/apps/APP1/appInfos":
            return 200, {"data": self.infos}
        if url == "/v1/apps/APP1/appStoreVersions":
            return 200, {"data": self.versions}
        return 404, {}

    def writes(self):
        return [request for request in self.requests if request[0] != "GET"]

    def close(self):
        self.server.shutdown()


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def watch(self, infos, versions, status=None):
        fake = FakeASC(infos, versions, status)
        self.addCleanup(fake.close)
        output = Path(self.tmp.name) / "github_output"
        output.write_text("")
        env = dict(os.environ, ASC_KEY_ID=KEY_ID, ASC_ISSUER_ID=ISSUER_ID, ASC_KEY_FILE=str(self.key),
                   ASC_API_BASE=fake.base, ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", GITHUB_OUTPUT=str(output))
        result = subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=120)
        result.fake, result.github_output = fake, output.read_text()
        return result

    def assert_lage(self, result, lage):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("LAGE="), 1, result.stdout)
        self.assertEqual(result.stdout.rstrip().splitlines()[-1], f"LAGE={lage}", result.stdout)
        self.assertIn(f"LAGE={lage}", result.github_output)
        self.assertEqual(result.fake.writes(), [])

    # AC-1, AC-4
    def test_editable_wins(self):
        self.assert_lage(self.watch(EDITABLE, [IOS_LIVE, mac("IN_REVIEW")]), "editierbar")
        self.assert_lage(self.watch(EDITABLE, [IOS_LIVE, mac("PENDING_DEVELOPER_RELEASE")]), "editierbar")
        two = [info("I1", "PREPARE_FOR_SUBMISSION"), info("I2", "PREPARE_FOR_SUBMISSION")]
        self.assert_lage(self.watch(two, [mac("IN_REVIEW")]), "editierbar")

    # AC-2
    def test_mac_left_review(self):
        for state in ("PENDING_DEVELOPER_RELEASE", "REJECTED", "READY_FOR_SALE"):
            result = self.watch(LOCKED, [IOS_LIVE, mac(state)])
            self.assert_lage(result, "mac_fertig")
            self.assertIn(f"state={state}", result.stdout)

    def test_newest_mac_version_counts(self):
        older_done = version("V3", "MAC_OS", "0.9", "READY_FOR_SALE")
        self.assert_lage(self.watch(LOCKED, [older_done, mac("IN_REVIEW", "1.0")]), "warten")
        self.assert_lage(self.watch(LOCKED, [mac("IN_REVIEW", "0.9"), version("V4", "MAC_OS", "1.0", "REJECTED")]),
                         "mac_fertig")

    # AC-3
    def test_mac_in_review_waits(self):
        for state in ("IN_REVIEW", "WAITING_FOR_REVIEW", "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"):
            self.assert_lage(self.watch(LOCKED, [IOS_LIVE, mac(state)]), "warten")

    # AC-3
    def test_missing_data_waits(self):
        self.assert_lage(self.watch(LOCKED, [IOS_LIVE]), "warten")
        self.assert_lage(self.watch([], []), "warten")
        self.assert_lage(self.watch([{"id": "I1", "attributes": {}}], [{"id": "V", "attributes": {}}]), "warten")
        self.assert_lage(self.watch(LOCKED, [mac(None)]), "warten")

    # AC-5
    def test_5xx_stays_quiet(self):
        for status in (500, 503):
            result = self.watch(LOCKED, [mac("REJECTED")], status=status)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("::notice::ASC nicht erreichbar, nichts gemeldet", result.stdout)
            self.assertEqual(result.stdout.rstrip().splitlines()[-1], "LAGE=warten")
            self.assertIn("LAGE=warten", result.github_output)
            self.assertNotIn("::error::", result.stdout)

    # AC-6
    def test_401_fails_loudly(self):
        for status in (401, 403):
            result = self.watch(LOCKED, [mac("REJECTED")], status=status)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("::error::", result.stdout)
            self.assertNotIn("LAGE=", result.stdout)
            self.assertNotIn("LAGE=", result.github_output)

    # AC-7
    def test_output_has_no_secrets(self):
        runs = [self.watch(EDITABLE, [mac("REJECTED")]), self.watch(LOCKED, [mac("IN_REVIEW")]),
                self.watch(LOCKED, [], status=503), self.watch(LOCKED, [], status=401)]
        for result in runs:
            text = result.stdout + result.stderr + result.github_output
            for secret in (RAW_SECRET, KEY_ID, ISSUER_ID, "PRIVATE KEY", "Bearer"):
                self.assertNotIn(secret, text)
        self.assertIn("appinfo id=I2 state=PREPARE_FOR_SUBMISSION", runs[0].stdout)
        self.assertIn("version MAC_OS 1.0 state=REJECTED", runs[0].stdout)


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WORKFLOW.read_text(encoding="utf-8")

    # AC-8
    def test_workflow_shape(self):
        text = self.text
        self.assertRegex(text, r"schedule:\s*\n\s*- cron: \"17 7 \* \* \*\"")
        self.assertIn("workflow_dispatch:", text)
        self.assertRegex(text, r"contents: read")
        self.assertRegex(text, r"issues: write")
        self.assertNotRegex(text, r"(contents|actions|variables|pull-requests|id-token): write")
        self.assertRegex(text, r"concurrency:\s*\n\s*group: asc-watch-appinfo\s*\n\s*cancel-in-progress: false")
        self.assertIn("timeout-minutes: 10", text)
        self.assertIn("runs-on: ubuntu-latest", text)
        self.assertIn("python3 scripts/test_asc_watch_appinfo.py", text)
        self.assertLess(text.index("scripts/test_asc_watch_appinfo.py"), text.index("scripts/asc_watch_appinfo.py"))
        self.assertIn("umask 077", text)
        self.assertIn("trap", text)

    # AC-8: nur lesen
    def test_workflow_never_writes_to_asc(self):
        self.assertNotRegex(self.text, r"-X\s*(POST|PATCH|PUT|DELETE)")
        self.assertNotIn("asc_app_info.py", self.text)

    # AC-9, AC-10
    def test_comment_once_per_lage(self):
        text = self.text
        self.assertIn("<!-- wachter-846:${LAGE} -->", text)
        self.assertIn("gh issue view 837 --json comments", text)
        self.assertEqual(text.count("gh issue comment 837"), 1)
        self.assertIn("--body-file", text)
        self.assertIn("asc-app-info.yml aktion=untertitel", text)
        self.assertIn("Mac 1.0 hat die Prüfung verlassen", text)
        self.assertRegex(text, r"LAGE.*(!=|==).*warten|warten\)")
        marker_check = text.index("gh issue view 837")
        self.assertLess(marker_check, text.index("gh issue comment 837"))
        self.assertTrue(re.search(r"GITHUB_TOKEN", text))


if __name__ == "__main__":
    unittest.main()
