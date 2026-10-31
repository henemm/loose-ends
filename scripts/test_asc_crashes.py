"""Tests für asc_crashes.py (#773 Schnitt 1).

Aufruf: python3 scripts/test_asc_crashes.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; ob Apple die Pfade so beantwortet, zeigt nur der echte Lauf.
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

SCRIPT = Path(__file__).resolve().parent / "asc_crashes.py"
LIST = "/v1/apps/APP1/betaFeedbackCrashSubmissions"
MARKERS = ("tester-MARKER@example.test", "COMMENT-MARKER", "iPhone-MARKER", "LOG-MARKER", "LOCALE-MARKER",
           "ZONE-MARKER", "BEGIN", "PRIVATE KEY", "Bearer", "eyJ")
LOG = "Exception Type: EXC_CRASH\nLOG-MARKER Grüße\n"


def submission(sid, platform="IOS"):
    return {"type": "betaFeedbackCrashSubmissions", "id": sid, "attributes": {
        "appPlatform": platform, "buildBundleId": "com.henning.looseends", "createdDate": "2026-10-30T08:00:00Z",
        "email": "tester-MARKER@example.test", "comment": "COMMENT-MARKER", "deviceModel": "iPhone-MARKER",
        "locale": "LOCALE-MARKER", "timeZone": "ZONE-MARKER", "batteryPercentage": 80}}


class FakeASC:
    """Liste in Seiten, Bericht je Id; `statuses[pfad]` spielt eine Statusfolge ab (letzter Wert bleibt)."""

    def __init__(self, pages, logs=None, statuses=None):
        self.pages, self.logs, self.statuses, self.requests = pages, logs or {}, statuses or {}, []
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
                fake.requests.append(("GET", self.path))
                path, _, query = self.path.partition("?")
                queue = fake.statuses.get(path)
                status = (queue.pop(0) if len(queue) > 1 else queue[0]) if queue else 200
                if status != 200:
                    return self.reply(status)
                if path == "/v1/apps":
                    return self.reply(200, {"data": [{"id": "APP1"}]})
                if path == LIST:
                    index = int(query.split("page=")[1]) if "page=" in query else 0
                    body = {"data": fake.pages[index]}
                    if index + 1 < len(fake.pages):
                        body["links"] = {"next": f"{fake.base}{LIST}?limit=200&page={index + 1}"}
                    return self.reply(200, body)
                sid = path.split("/")[3] if path.endswith("/crashLog") else None
                if sid in fake.logs:
                    return self.reply(200, {"data": {"type": "betaCrashLogs", "id": sid,
                                                     "attributes": {"logText": fake.logs[sid]}}})
                self.reply(404)

            def other(self):
                fake.requests.append((self.command, self.path))
                self.reply(405)

            do_POST = do_PATCH = do_DELETE = do_PUT = other

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def close(self):
        self.server.shutdown()

    def hits(self, path):
        return [p for _, p in self.requests if p.split("?")[0] == path]


class CrashesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.out = self.root / "out" / "crashes"
        self.key = self.root / "key.p8"
        pem = self.root / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, fake, args=None, **overrides):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key),
                   ASC_API_BASE=fake.base if fake else "http://127.0.0.1:9", ASC_POLL_SECONDS="0")
        env.update(overrides)
        args = [str(self.out)] if args is None else args
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def fake(self, *args, **kwargs):
        fake = FakeASC(*args, **kwargs)
        self.addCleanup(fake.close)
        return fake

    def assert_no_personal_data(self, result):
        for marker in MARKERS:
            self.assertNotIn(marker, result.stdout + result.stderr, marker)

    def test_no_submissions(self):
        result = self.run_script(self.fake([[]]))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.strip().splitlines(), ["keine Absturzmeldungen"])
        self.assertTrue(self.out.is_dir())
        self.assertEqual(list(self.out.iterdir()), [])

    def test_two_pages_via_links_next(self):
        fake = self.fake([[submission("S1"), submission("S2")], [submission("S3")]], logs={"S1": LOG})
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("meldung id="), 3)
        self.assertIn("zusammenfassung meldungen=3 mit_bericht=1 ohne_bericht=2", result.stdout)
        lists = fake.hits(LIST)
        self.assertIn("limit=200", lists[0])
        self.assertEqual(sum("page=1" in p for p in lists), 1)

    def test_files_have_expected_content(self):
        result = self.run_script(self.fake([[submission("S1")]], logs={"S1": LOG}))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads((self.out / "S1.json").read_text(encoding="utf-8")),
                         submission("S1")["attributes"])
        self.assertEqual((self.out / "S1.crash").read_bytes().decode("utf-8"), LOG)
        for name in ("S1.json", "S1.crash"):
            self.assertEqual((self.out / name).stat().st_mode & 0o777, 0o600, name)

    def test_missing_crashlog_counts_as_without_report(self):
        result = self.run_script(self.fake([[submission("S1"), submission("S2")]], logs={"S1": LOG}))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        line = next(l for l in result.stdout.splitlines() if "id=S2 " in l)
        self.assertTrue(line.endswith("bericht=nein"), line)
        self.assertIn("zusammenfassung meldungen=2 mit_bericht=1 ohne_bericht=1", result.stdout)
        self.assertTrue((self.out / "S2.json").exists())
        self.assertFalse((self.out / "S2.crash").exists())

    def test_empty_logtext_counts_as_without_report(self):
        result = self.run_script(self.fake([[submission("S1")]], logs={"S1": ""}))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("bericht=nein", result.stdout)
        self.assertFalse((self.out / "S1.crash").exists())

    def test_server_error_once_is_retried(self):
        fake = self.fake([[submission("S1")]], logs={"S1": LOG}, statuses={LIST: [500, 200]})
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.out / "S1.json").exists() and (self.out / "S1.crash").exists())

    def test_server_error_always_exits_1(self):
        fake = self.fake([[submission("S1")]], statuses={LIST: [500]})
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout)
        self.assertEqual(len(fake.hits(LIST)), 5)

    def test_forbidden_exits_1(self):
        for statuses in ({LIST: [403]}, {"/v1/betaFeedbackCrashSubmissions/S1/crashLog": [403]}):
            with self.subTest(statuses=statuses):
                result = self.run_script(self.fake([[submission("S1")]], logs={"S1": LOG}, statuses=statuses))
                self.assertEqual(result.returncode, 1)
                self.assertIn("::error::", result.stdout)
                self.assertIn("HTTP 403", result.stdout)
                self.assertEqual(list(self.out.glob("*")) if self.out.exists() else [], [])
                self.assert_no_personal_data(result)

    def test_log_has_no_personal_data(self):
        result = self.run_script(self.fake([[submission("S1")]], logs={"S1": LOG}))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_no_personal_data(result)
        line = next(l for l in result.stdout.splitlines() if l.startswith("meldung "))
        for part in ("id=S1", "bundle=com.henning.looseends", "plattform=IOS", "datum=2026-10-30T08:00:00Z"):
            self.assertIn(part, line)

    def test_both_platforms_in_one_run(self):
        fake = self.fake([[submission("S1", "IOS"), submission("S2", "MAC_OS")]])
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("plattform=IOS", result.stdout)
        self.assertIn("plattform=MAC_OS", result.stdout)
        self.assertFalse(any("filter" in p for p in fake.hits(LIST)))

    def test_only_get_requests(self):
        fake = self.fake([[submission("S1"), submission("S2")]], logs={"S1": LOG})
        self.assertEqual(self.run_script(fake).returncode, 0)
        self.assertTrue(fake.requests)
        self.assertEqual({method for method, _ in fake.requests}, {"GET"})

    def test_unsafe_id_exits_1(self):
        for sid in ("../evil", "x\n", "a/b"):
            with self.subTest(sid=sid):
                result = self.run_script(self.fake([[submission(sid)]], logs={sid: LOG}))
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("::error::", result.stdout)
                self.assertEqual(sorted(p.name for p in self.root.rglob("*") if p.is_file()), ["key.p8", "key.pem"])

    def test_target_is_a_file_exits_1(self):
        self.out.parent.mkdir(parents=True)
        self.out.write_text("")
        result = self.run_script(self.fake([[submission("S1")]], logs={"S1": LOG}))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    def test_usage_and_missing_environment(self):
        result = self.run_script(None, args=[])
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)
        result = self.run_script(None, ASC_KEY_ID="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Missing environment", result.stdout)


if __name__ == "__main__":
    unittest.main()
