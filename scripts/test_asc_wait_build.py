"""Tests für asc_wait_build.py und den Job `confirm` in testflight.yml (#183).

Aufruf: python3 scripts/test_asc_wait_build.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; Apples echte Antworten zeigt nur der echte Lauf.
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_wait_build.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "testflight.yml"
BUILD = "42"
sys.path.insert(0, str(SCRIPTS))
import asc_wait_build  # noqa: E402


def b64d(part):
    return base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))


def der_int(raw):
    raw = raw.lstrip(b"\0") or b"\0"
    if raw[0] & 0x80:
        raw = b"\0" + raw
    return b"\x02" + bytes([len(raw)]) + raw


def rs_to_der(sig):
    body = der_int(sig[:32]) + der_int(sig[32:])
    return b"\x30" + bytes([len(body)]) + body


def openssl(*args, data=None):
    return subprocess.run(["openssl", *args], input=data, capture_output=True, check=True).stdout


def make_key(directory, name):
    """Erzeugt einen EC-Schlüssel (prime256v1): (.p8-Pfad, öffentlicher Schlüssel als PEM-Pfad)."""
    pem, p8, pub = (str(directory / f"{name}.{ext}") for ext in ("pem", "p8", "pub"))
    openssl("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem)
    openssl("pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", p8)
    openssl("ec", "-in", pem, "-pubout", "-out", pub)
    return p8, pub


def build(version=BUILD, state="VALID"):
    return {"id": f"b-{version}", "attributes": {
        "version": version, "processingState": state, "uploadedDate": "2026-10-03T10:00:00+00:00"}}


class Raw:
    """Rohantwort im Skript: Status und Rumpf werden unverändert gesendet."""

    def __init__(self, status, body):
        self.status, self.body = status, body


class FakeASC:
    """Antwortet auf /v1/apps und /v1/builds; Builds-Antworten laufen als Skript, die letzte wiederholt sich.
    Ein Raw-Eintrag wird wörtlich gesendet; apps_raw wird vor der Apps-Antwort abgearbeitet."""

    def __init__(self, directory, pub, builds_script, apps=None, apps_raw=()):
        self.tokens, self.builds_script, self.paths = [], list(builds_script), []
        self.apps = [{"id": "APP1"}] if apps is None else apps
        self.apps_raw = list(apps_raw)
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                fake.paths.append(self.path)
                token = self.headers.get("Authorization", "").removeprefix("Bearer ")
                if not fake.valid(token, directory, pub):
                    return self.reply(401, {"errors": [{"status": "401"}]})
                if self.path.startswith("/v1/apps"):
                    if fake.apps_raw:
                        return self.reply(None, fake.apps_raw.pop(0))
                    return self.reply(200, {"data": fake.apps})
                fake.tokens.append(token)
                data = fake.builds_script.pop(0) if len(fake.builds_script) > 1 else fake.builds_script[0]
                self.reply(200, data if isinstance(data, Raw) else {"data": data})

            def reply(self, status, body):
                if isinstance(body, Raw):
                    status, raw = body.status, body.body
                else:
                    raw = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def valid(self, token, directory, pub):
        try:
            head, payload, sig = token.split(".")
            header, claims = json.loads(b64d(head)), json.loads(b64d(payload))
            assert header == {"alg": "ES256", "kid": "KEYID123", "typ": "JWT"}, header
            assert claims["iss"] == "ISSUER-UUID" and claims["aud"] == "appstoreconnect-v1", claims
            assert 0 < claims["exp"] - claims["iat"] <= 1200, claims
            raw = b64d(sig)
            assert len(raw) == 64, len(raw)
            sig_file, data_file = directory / "sig.der", directory / "data.txt"
            sig_file.write_bytes(rs_to_der(raw))
            data_file.write_bytes(f"{head}.{payload}".encode())
            subprocess.run(["openssl", "dgst", "-sha256", "-verify", pub, "-signature", str(sig_file),
                            str(data_file)], capture_output=True, check=True)
            return True
        except Exception:
            return False

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.p8, self.pub = make_key(self.dir, "asc")
        self.addCleanup(self.tmp.cleanup)

    def run_script(self, builds_script, timeout="5", pub=None, apps=None, build_no=BUILD, apps_raw=()):
        fake = FakeASC(self.dir, pub or self.pub, builds_script, apps, apps_raw)
        self.addCleanup(fake.close)
        env = dict(os.environ, ASC_KEY_ID="KEYID123", ASC_ISSUER_ID="ISSUER-UUID", ASC_KEY_FILE=self.p8,
                   ASC_API_BASE=fake.url, ASC_POLL_SECONDS="0.05", ASC_TIMEOUT_SECONDS=timeout)
        try:
            result = subprocess.run([sys.executable, str(SCRIPT), build_no], env=env, capture_output=True,
                                    text=True, timeout=30)
        except subprocess.TimeoutExpired:
            self.fail("asc_wait_build.py lief länger als 30 s")
        return result, fake

    def test_2_valid_at_once(self):
        result, fake = self.run_script([[build()]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, rf"build={BUILD} processingState=VALID uploadedDate=2026-10-03")
        self.assertIn("filter[app]=APP1", fake.paths[-1])

    def test_3_processing_then_valid_uses_a_new_token_per_round(self):
        result, fake = self.run_script([[build(state="PROCESSING")], [build(state="PROCESSING")], [build()]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(fake.tokens), 3)
        self.assertEqual(len(set(fake.tokens)), 3)

    def test_4_invalid_and_failed_exit_nonzero(self):
        for state in ("INVALID", "FAILED"):
            with self.subTest(state=state):
                result, _ = self.run_script([[build(state=state)]])
                self.assertEqual(result.returncode, 1)
                self.assertIn("::error::", result.stdout + result.stderr)
                self.assertIn(state, result.stdout + result.stderr)

    def test_5_timeout_while_processing(self):
        result, _ = self.run_script([[build(state="PROCESSING")]], timeout="1")
        self.assertEqual(result.returncode, 1)
        self.assertRegex((result.stdout + result.stderr).lower(), r"::error::.*not valid")

    def test_6_empty_list_means_wait(self):
        result, fake = self.run_script([[], [], [build()]])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nicht-gelistet", result.stdout)
        self.assertEqual(len(fake.tokens), 3)

    def test_7_record_with_wrong_version_is_ignored(self):
        result, _ = self.run_script([[build(version="999")]], timeout="1")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("processingState=VALID", result.stdout)

    def test_8_wrong_signature_is_rejected_and_fails(self):
        _, other_pub = make_key(self.dir, "other")
        result, _ = self.run_script([[build()]], pub=other_pub)
        self.assertEqual(result.returncode, 1)
        self.assertIn("401", result.stdout + result.stderr)

    def test_8b_unknown_app_fails(self):
        result, _ = self.run_script([[build()]], apps=[])
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout + result.stderr)

    def test_9_no_secrets_in_output(self):
        body = "".join(l for l in Path(self.p8).read_text().splitlines() if "-----" not in l)
        for state, code in (("VALID", 0), ("INVALID", 1)):
            with self.subTest(state=state):
                result, fake = self.run_script([[build(state=state)]])
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, code, output)
                self.assertIn(state, output)
                self.assertTrue(fake.tokens, "Skript hat nie ein Token gesendet")
                self.assertNotIn(body, output)
                self.assertNotIn(body[:40], output)
                for token in fake.tokens:
                    self.assertNotIn(token, output)
                    self.assertNotIn(token.split(".")[2], output)

    def test_9b_malformed_200_bodies_mean_retry(self):
        for name, raw in (("html", Raw(200, b"<html>busy</html>")), ("empty", Raw(200, b"")),
                          ("list", Raw(200, b"[1, 2]")), ("data-object", Raw(200, b'{"data": {"id": "x"}}')),
                          ("data-strings", Raw(200, b'{"data": ["x"]}'))):
            with self.subTest(body=name):
                result, _ = self.run_script([raw, [build()]], apps_raw=[raw])
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertNotIn("Traceback", output)
                self.assertNotIn("busy", output)

    def test_9c_408_and_429_mean_retry(self):
        for status in (408, 429):
            with self.subTest(status=status):
                raw = Raw(status, b'{"errors": []}')
                result, _ = self.run_script([raw, [build()]], apps_raw=[raw])
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertIn(str(status), output)
                self.assertNotIn("Traceback", output)

    def test_9d_other_4xx_still_fatal(self):
        result, _ = self.run_script([Raw(404, b"{}")])
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout)


class DerTests(unittest.TestCase):
    def test_der_to_rs_fixed_bytes(self):
        s = bytes(range(1, 33))
        high = b"\x80" + bytes(31)
        cases = {
            "r=1 kurz": (b"\x30\x25\x02\x01\x01\x02\x20" + s, bytes(31) + b"\x01" + s),
            "r mit 0x00 und High-Bit": (b"\x30\x45\x02\x21\x00" + high + b"\x02\x20" + s, high + s),
            "Langform 0x81": (b"\x30\x81\x46\x02\x21\x00" + high + b"\x02\x21\x00" + high, high + high),
        }
        for name, (der, expected) in cases.items():
            with self.subTest(case=name):
                rs = asc_wait_build.der_to_rs(der)
                self.assertEqual(len(rs), 64)
                self.assertEqual(rs, expected)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text()

    def job(self, name):
        match = re.search(rf"(?m)^  {name}:\n((?:(?:    .*)?\n)+)", self.text)
        self.assertIsNotNone(match, f"Job {name} fehlt in testflight.yml")
        return match.group(1)

    def test_10_confirm_job_shape(self):
        confirm = self.job("confirm")
        self.assertRegex(confirm, r"(?m)^    needs: upload$")
        self.assertRegex(confirm, r"(?m)^    runs-on: ubuntu-latest$")
        self.assertGreaterEqual(int(re.search(r"(?m)^    timeout-minutes: (\d+)$", confirm).group(1)), 50)
        self.assertIn("scripts/asc_wait_build.py", confirm)
        self.assertIn("""trap 'rm -f "$RUNNER_TEMP/asc_key.p8"' EXIT""", confirm)
        umask, printf = confirm.find("umask 077"), confirm.find("printf '%s\\n'")
        self.assertNotEqual(umask, -1)
        self.assertNotEqual(printf, -1)
        self.assertLess(umask, printf)
        self.assertRegex(confirm, r'ASC_KEY_FILE="\$RUNNER_TEMP/[^"]+\.p8"')
        self.assertRegex(confirm, r'> "\$RUNNER_TEMP/[^"]+\.p8"')

    def test_10_upload_job_keeps_every_step(self):
        steps = re.findall(r"(?m)^      - (?:name: (.+)|uses: .+)$", self.job("upload"))
        for name in ("Check the secrets are in place", "Select Xcode 27.0", "Archive",
                     "Verify the archive is built against the iOS 27 SDK", "Upload to TestFlight",
                     "Show what went wrong", "Upload logs", "Remove the key"):
            self.assertIn(name, steps)

    def test_10_run_blocks_are_valid_bash(self):
        lines, blocks, current = self.text.splitlines(), [], None
        for line in lines:
            if current is not None:
                if line.strip() == "" or len(line) - len(line.lstrip()) > current[0]:
                    current[1].append(line)
                    continue
                blocks.append("\n".join(current[1]))
                current = None
            match = re.match(r"^(\s*)run: \|$", line)
            if match:
                current = (len(match.group(1)), [])
        if current:
            blocks.append("\n".join(current[1]))
        self.assertGreaterEqual(len(blocks), 8)
        for block in blocks:
            script = re.sub(r"\$\{\{.*?\}\}", "X", block)
            result = subprocess.run(["bash", "-n"], input=script, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr + "\n" + script[:200])

    def test_1_table_goes_to_the_log_too(self):
        verify = re.search(r"(?s)- name: Verify the archive.*?(?=\n      - name: Write export)", self.text).group(0)
        self.assertNotIn('>> "$SUMMARY"', verify)
        self.assertIn("tee -a", verify)
        self.assertIn("/dev/null", verify)


if __name__ == "__main__":
    unittest.main()
