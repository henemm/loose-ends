"""Tests für asc_crashes.py (#773 Schnitt 1) und den Handlauf asc-crashes.yml (#773 Schnitt 2).

Aufruf: python3 scripts/test_asc_crashes.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; ob Apple die Pfade so beantwortet, zeigt nur der echte Lauf.
Der Workflow wird als Text geprüft, der Verschlüsselungsweg mit gpg und dem öffentlichen Schlüssel im Repo.
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

SCRIPT = Path(__file__).resolve().parent / "asc_crashes.py"
REPO = Path(__file__).resolve().parents[1]
WORKFLOW = REPO / ".github" / "workflows" / "asc-crashes.yml"
RECIPIENT = REPO / ".github" / "crash-recipient.asc"
PLAIN_MARKER = b"CRASH-PLAIN-MARKER"
LIST = "/v1/apps/APP1/betaFeedbackCrashSubmissions"
MARKERS = ("tester-MARKER@example.test", "COMMENT-MARKER", "iPhone-MARKER", "LOG-MARKER", "LOCALE-MARKER",
           "ZONE-MARKER", "BEGIN", "PRIVATE KEY", "Bearer", "eyJ")
LOG = "Exception Type: EXC_CRASH\nLOG-MARKER Grüße\n"


def submission(sid, platform="IOS"):
    return {"type": "betaFeedbackCrashSubmissions", "id": sid, "attributes": {
        "appPlatform": platform, "buildBundleId": "com.henning.looseends", "createdDate": "2026-10-30T08:00:00Z",
        "email": "tester-MARKER@example.test", "comment": "COMMENT-MARKER", "deviceModel": "iPhone-MARKER",
        "locale": "LOCALE-MARKER", "timeZone": "ZONE-MARKER", "batteryPercentage": 80}}


def with_attributes(sid, **attributes):
    record = submission(sid)
    record["attributes"].update(attributes)
    return record


class FakeASC:
    """Liste in Seiten, Bericht je Id; `statuses[pfad]` spielt eine Statusfolge ab (letzter Wert bleibt)."""

    def __init__(self, pages, logs=None, statuses=None, loop=False):
        self.pages, self.logs, self.statuses, self.requests = pages, logs or {}, statuses or {}, []
        self.loop = loop
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
                    elif fake.loop:
                        body["links"] = {"next": f"{fake.base}{LIST}?limit=200"}
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
        self.server.server_close()

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

    def run_script(self, fake, args=None, timeout=None, **overrides):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key),
                   ASC_API_BASE=fake.base if fake else "http://127.0.0.1:9", ASC_POLL_SECONDS="0")
        env.update(overrides)
        args = [str(self.out)] if args is None else args
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True,
                              timeout=timeout)

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

    def test_app_lookup_server_error_exits_1(self):
        fake = self.fake([[submission("S1")]], logs={"S1": LOG}, statuses={"/v1/apps": [500]})
        result = self.run_script(fake, ASC_TIMEOUT_SECONDS="1")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        self.assertEqual(len(fake.hits("/v1/apps")), 5)
        self.assertEqual(list(self.out.glob("*")) if self.out.exists() else [], [])

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

    def test_non_string_attribute_becomes_unbekannt(self):
        record = with_attributes("S1", buildBundleId=42, appPlatform={"name": "IOS"}, createdDate=["2026"])
        result = self.run_script(self.fake([[record]], logs={"S1": LOG}))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        line = next(l for l in result.stdout.splitlines() if l.startswith("meldung "))
        self.assertIn("bundle=unbekannt plattform=unbekannt datum=unbekannt", line)
        self.assertEqual(json.loads((self.out / "S1.json").read_text(encoding="utf-8")), record["attributes"])

    def test_unsafe_attribute_becomes_unbekannt(self):
        unsafe = with_attributes("S1", buildBundleId="a\n::add-mask::x", appPlatform="::error::boom",
                                 createdDate="2026 10 30")
        too_long = with_attributes("S2", buildBundleId="a" * 65)
        result = self.run_script(self.fake([[unsafe, too_long]]))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual([l for l in lines if l.startswith("::")], [], result.stdout)
        first = next(l for l in lines if "id=S1 " in l)
        self.assertIn("bundle=unbekannt plattform=unbekannt datum=unbekannt", first)
        second = next(l for l in lines if "id=S2 " in l)
        self.assertIn("bundle=unbekannt plattform=IOS datum=2026-10-30T08:00:00Z", second)

    def test_only_own_error_line_starts_with_colons(self):
        record = with_attributes("S1", appPlatform="IOS\n::error::injected")
        result = self.run_script(self.fake([[record]]))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([l for l in result.stdout.splitlines() if l.startswith("::")], [], result.stdout)
        result = self.run_script(self.fake([[record]], statuses={LIST: [403]}))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        colons = [l for l in result.stdout.splitlines() if l.startswith("::")]
        self.assertEqual(len(colons), 1, result.stdout)
        self.assertTrue(colons[0].startswith("::error::") and "HTTP 403" in colons[0], colons[0])

    def test_pagination_loop_exits_1(self):
        pages = [[submission("S1")], [submission("S2")]]
        fake = self.fake(pages, logs={"S1": LOG}, loop=True)
        try:
            result = self.run_script(fake, timeout=20)
        except subprocess.TimeoutExpired:
            self.fail(f"no stop after {len(fake.hits(LIST))} list requests")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        self.assertIn("Pagination loop", result.stdout)
        self.assertLessEqual(len(fake.hits(LIST)), len(pages))
        self.assertEqual([p for p in self.out.rglob("*") if p.is_file()] if self.out.exists() else [], [])


def gpg(*args, home=None, check=True):
    env = dict(os.environ, GNUPGHOME=str(home)) if home else None
    return subprocess.run(["gpg", "--batch", *args], env=env, capture_output=True, check=check)


def encrypt_like_workflow(folder, tar, cipher, home=None):
    """Packt und verschlüsselt mit denselben Schaltern wie asc-crashes.yml (Aufruf aus der Repo-Wurzel)."""
    subprocess.run(["tar", "-C", str(folder), "-cf", str(tar), "."], check=True)
    if not tar.exists():
        raise AssertionError(f"plain tar missing: {tar}")
    return gpg("--trust-model", "always", "--recipient-file", ".github/crash-recipient.asc",
               "--output", str(cipher), "--encrypt", str(tar), home=home, check=False)


def recipient_fingerprint():
    with tempfile.TemporaryDirectory() as home:
        listing = gpg("--show-keys", "--with-colons", str(RECIPIENT), home=home).stdout.decode()
    return next(l.split(":")[9] for l in listing.splitlines() if l.startswith("fpr:"))


class EncryptionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.home = self.root / "gnupg"
        self.home.mkdir(mode=0o700)
        self.folder = self.root / "crashes"
        self.folder.mkdir()
        (self.folder / "P1.json").write_text('{"appPlatform": "IOS"}', encoding="utf-8")
        (self.folder / "P1.crash").write_bytes(b"Exception Type: EXC_CRASH\n" + PLAIN_MARKER + b"\n")
        self.tar, self.cipher = self.root / "crashes.tar", self.root / "crashes.tar.gpg"
        self.cwd = os.getcwd()
        os.chdir(REPO)

    def tearDown(self):
        os.chdir(self.cwd)
        self.tmp.cleanup()

    def test_recipient_file_is_one_public_key(self):
        text = RECIPIENT.read_text(encoding="ascii")
        self.assertIn("BEGIN PGP PUBLIC KEY BLOCK", text)
        self.assertNotIn("PRIVATE KEY", text)
        listing = gpg("--show-keys", "--with-colons", str(RECIPIENT), home=self.home).stdout.decode()
        kinds = [l.split(":")[0] for l in listing.splitlines()]
        self.assertEqual(kinds.count("pub"), 1, listing)
        self.assertNotIn("sec", kinds)
        self.assertNotIn("ssb", kinds)

    def test_encrypt_with_recipient_file_hides_content(self):
        self.assertTrue(RECIPIENT.exists(), RECIPIENT)
        result = encrypt_like_workflow(self.folder, self.tar, self.cipher, home=self.home)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        data = self.cipher.read_bytes()
        self.assertTrue(data)
        self.assertNotIn(PLAIN_MARKER, data)

    def test_roundtrip_with_local_key(self):
        self.assertTrue(RECIPIENT.exists(), RECIPIENT)
        if gpg("--list-secret-keys", recipient_fingerprint(), check=False).returncode != 0:
            self.skipTest("secret key of the recipient is not in this keyring (CI)")
        self.assertEqual(encrypt_like_workflow(self.folder, self.tar, self.cipher).returncode, 0)
        plain, unpacked = self.root / "back.tar", self.root / "back"
        unpacked.mkdir()
        decrypted = gpg("--output", str(plain), "--decrypt", str(self.cipher), check=False)
        self.assertEqual(decrypted.returncode, 0, decrypted.stderr.decode())
        subprocess.run(["tar", "-C", str(unpacked), "-xf", str(plain)], check=True)
        for original in self.folder.iterdir():
            self.assertEqual((unpacked / original.name).read_bytes(), original.read_bytes(), original.name)


def run_blocks(text):
    """Inhalt jedes `run:`-Schlüssels, einzeilig oder als eingerückter Block."""
    blocks, lines = [], text.splitlines()
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(?:- )?run:\s*(.*)$", line)
        if not match:
            continue
        if match.group(2) not in ("|", ">", "|-", ">-"):
            blocks.append(match.group(2))
            continue
        indent, body = len(match.group(1)), []
        for following in lines[index + 1:]:
            if following.strip() and len(following) - len(following.lstrip()) <= indent:
                break
            body.append(following)
        blocks.append("\n".join(body))
    return blocks


def upload_paths(text):
    return re.findall(r"^\s*path:\s*(\S+)\s*$", text, re.M)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(WORKFLOW.exists(), WORKFLOW)
        self.text = WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_structure(self):
        text = self.text
        on = re.search(r"^on:\s*\n((?:[ \t]+.*\n|[ \t]*\n)*)", text, re.M)
        self.assertIsNotNone(on, "no on: block")
        self.assertIn("workflow_dispatch", on.group(1))
        for trigger in ("push", "pull_request", "schedule", "workflow_run", "release"):
            self.assertNotRegex(on.group(1), rf"\b{trigger}\b")
        permissions = re.search(r"^permissions:\s*\n\s+contents:\s*read\s*$", text, re.M)
        self.assertIsNotNone(permissions, "no permissions: contents: read")
        self.assertLess(permissions.start(), text.index("\njobs:"))
        self.assertIn("retention-days: 7", text)
        self.assertIn("if-no-files-found: error", text)
        self.assertTrue(upload_paths(text))
        self.assertTrue(all(p.endswith(".gpg") for p in upload_paths(text)), upload_paths(text))
        self.assertRegex(text, r"if:\s*steps\.[\w-]+\.outputs\.encrypted\s*==\s*'true'")
        script = "\n".join(run_blocks(text))
        for needed in ("--recipient-file .github/crash-recipient.asc", "set -euo pipefail", "umask 077", "trap ",
                       "::notice::", "encrypted=false", "encrypted=true"):
            self.assertIn(needed, script)
        self.assertRegex(script, r'scripts/asc_crashes\.py\s+"?\$RUNNER_TEMP/')

    def test_workflow_keeps_secrets_out_of_scripts(self):
        blocks = run_blocks(self.text)
        self.assertTrue(blocks)
        for block in blocks:
            self.assertNotIn("${{ secrets.", block)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertRegex(self.text, rf"(?m)^\s+{name}:\s*\$\{{\{{\s*secrets\.{name}\s*\}}\}}\s*$")
        for path in upload_paths(self.text):
            self.assertNotIn("crashes/", path)
            self.assertTrue(path.endswith("crashes.tar.gpg"), path)


if __name__ == "__main__":
    unittest.main()
