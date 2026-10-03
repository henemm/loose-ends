"""Tests für asc_cleanup_certs.py und die Aufräum-Schritte in testflight.yml (#191).

Aufruf: python3 scripts/test_asc_cleanup_certs.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; wie Apple die Zertifikate im Konto tatsächlich
füllt, zeigt nur der Probelauf (cleanup_dry_run=true). Die Tests nehmen nur die Felder an, die das
Skript selbst prüft: certificateType und name/displayName.
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
SCRIPT = SCRIPTS / "asc_cleanup_certs.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "testflight.yml"
DOC = SCRIPTS.parent / "docs" / "reference" / "testflight.md"
sys.path.insert(0, str(SCRIPTS))
from test_asc_wait_build import FakeASC, make_key  # noqa: E402  (Token-Prüfung und Schlüssel wiederverwendet)

CLEAR_BEFORE = "Clear leftover development certificates"
CLEAR_AFTER = "Clear the development certificates of this run"


def cert(cid, type_="DEVELOPMENT", name="Apple Development: Created via API", key="name"):
    attributes = {"certificateType": type_, "expirationDate": "2027-10-03T10:00:00.000+0000"}
    if key:
        attributes[key] = name
    return {"id": cid, "type": "certificates", "attributes": attributes}


class FakeCerts:
    """Antwortet auf GET /v1/certificates (optional seitenweise) und DELETE /v1/certificates/{id}.
    Ein gelöschtes Zertifikat verschwindet aus der Liste; delete_status überschreibt je ID die Antwort."""

    def __init__(self, directory, pub, certs, page_size=None, list_status=200, next_url=None):
        self.certs, self.deletes, self.paths, self.tokens = list(certs), [], [], []
        self.delete_status, self.next_url, self.page_size = {}, next_url, page_size
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def authorized(self):
                token = self.headers.get("Authorization", "").removeprefix("Bearer ")
                fake.tokens.append(token)
                if FakeASC.valid(fake, token, directory, pub):
                    return True
                self.reply(401, {"errors": [{"status": "401"}]})
                return False

            def do_GET(self):
                fake.paths.append(self.path)
                if not self.authorized():
                    return
                if list_status != 200:
                    return self.reply(list_status, {"errors": [{"status": str(list_status)}]})
                start = int(self.path.split("cursor=")[1]) if "cursor=" in self.path else 0
                size = fake.page_size or len(fake.certs) or 1
                body = {"data": fake.certs[start:start + size]}
                if fake.next_url and start == 0:
                    body["links"] = {"next": fake.next_url}
                elif fake.page_size and start + size < len(fake.certs):
                    body["links"] = {"next": f"{fake.url}/v1/certificates?limit=200&cursor={start + size}"}
                self.reply(200, body)

            def do_DELETE(self):
                fake.paths.append(self.path)
                if not self.authorized():
                    return
                cid = self.path.rsplit("/", 1)[1]
                status = fake.delete_status.get(cid, 204)
                if status == 204:
                    fake.deletes.append(cid)
                    fake.certs = [c for c in fake.certs if c["id"] != cid]
                else:
                    fake.deletes.append(cid)
                self.reply(status, {} if status != 204 else None)

            def reply(self, status, body):
                raw = b"" if body is None else json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class Foreign:
    """Fremder Host: zählt jede Anfrage, die ihn erreicht."""

    def __init__(self):
        self.requests = []
        foreign = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                foreign.requests.append(self.headers.get("Authorization"))
                self.send_response(200)
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"{}")

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.p8, self.pub = make_key(self.dir, "asc")
        self.addCleanup(self.tmp.cleanup)

    def run_script(self, certs, args=(), pub=None, summary=None, **fake_options):
        fake = FakeCerts(self.dir, pub or self.pub, certs, **fake_options)
        self.addCleanup(fake.close)
        env = dict(os.environ, ASC_KEY_ID="KEYID123", ASC_ISSUER_ID="ISSUER-UUID", ASC_KEY_FILE=self.p8,
                   ASC_API_BASE=fake.url)
        env.pop("GITHUB_STEP_SUMMARY", None)
        if summary:
            env["GITHUB_STEP_SUMMARY"] = str(summary)
        try:
            result = subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True,
                                    text=True, timeout=30)
        except subprocess.TimeoutExpired:
            self.fail("asc_cleanup_certs.py lief länger als 30 s")
        return result, fake

    def test_2_mixed_list_deletes_exactly_the_two_chosen(self):
        mixed = [cert("DEV111111"), cert("DEV222222"), cert("DIST33333", "DISTRIBUTION"),
                 cert("OWN444444", name="Apple Development: Henning Emmrich (XK87E2B3VR)"),
                 cert("OTH555555", "MAC_DEVELOPMENT", "Other Name"), cert("NON666666", key=None)]
        result, fake = self.run_script(mixed)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sorted(fake.deletes), ["DEV111111", "DEV222222"])

    def test_3_both_development_types_are_chosen(self):
        result, fake = self.run_script([cert("A11111", "DEVELOPMENT"), cert("B22222", "IOS_DEVELOPMENT")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sorted(fake.deletes), ["A11111", "B22222"])

    def test_3b_display_name_is_the_fallback_for_name(self):
        result, fake = self.run_script([cert("D11111", key="displayName")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(fake.deletes, ["D11111"])

    def test_4_nothing_else_is_ever_deleted(self):
        singles = {"distribution": cert("S11111", "DISTRIBUTION"),
                   "other name": cert("S22222", name="Henning's Mac"),
                   "other type": cert("S33333", "MAC_DEVELOPMENT"),
                   "no name field": cert("S44444", key=None),
                   "name with other case": cert("S55555", name="created via api"),
                   "name without Apple prefix": cert("S66666", name="Created via API"),
                   "own cert from probe run": cert("S77777", name="Apple Development: HENNING EMMRICH"),
                   "other person from probe run": cert("S88888", name="Apple Development: Johannes Emmrich")}
        for label, single in singles.items():
            with self.subTest(case=label):
                result, fake = self.run_script([single])
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(fake.deletes, [])

    def test_5_dry_run_deletes_nothing_and_lists(self):
        result, fake = self.run_script([cert("DEV111111"), cert("OWN444444", name="Henning")], args=["--dry-run"])
        output = result.stdout
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(fake.deletes, [])
        self.assertRegex(output, r"id=DEV111… aktion=widerruf")
        self.assertRegex(output, r"id=OWN444… aktion=bleibt")
        self.assertIn("wuerde-widerrufen=1", output)
        self.assertIn("widerrufen=0", output)
        self.assertIn("felder=", output)

    def test_6_count_line_matches_the_list_and_goes_to_the_summary(self):
        summary = self.dir / "summary.md"
        result, fake = self.run_script([cert("DEV111111"), cert("DEV222222"), cert("DIST33333", "DISTRIBUTION")],
                                       summary=summary)
        line = "zertifikate vorher=3 nachher=1 widerrufen=2"
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(line, result.stdout)
        self.assertIn(line, summary.read_text())
        self.assertEqual(len(fake.certs), 1)

    def test_7_pagination_reads_links_next(self):
        certs = [cert("P1" + str(i) * 4, "DISTRIBUTION") for i in range(2)] + [cert("PAGE2WANT")]
        result, fake = self.run_script(certs, page_size=2)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(fake.deletes, ["PAGE2WANT"])

    def test_7b_foreign_host_in_links_next_aborts_before_a_token_goes_there(self):
        foreign = Foreign()
        self.addCleanup(foreign.close)
        result, fake = self.run_script([cert("DEV111111")], next_url=foreign.url + "/v1/certificates?x=1")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(foreign.requests, [])
        self.assertEqual(fake.deletes, [])

    def test_8_401_and_403_on_listing_exit_1_without_delete(self):
        for status in (401, 403):
            with self.subTest(status=status):
                result, fake = self.run_script([cert("DEV111111")], list_status=status)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 1)
                self.assertIn(str(status), output)
                self.assertIn("::error::", output)
                self.assertEqual(fake.deletes, [])

    def test_9_failed_revoke_does_not_stop_the_rest_and_is_loud(self):
        fake_certs = [cert("FAIL11111"), cert("GOOD22222")]
        fake = FakeCerts(self.dir, self.pub, fake_certs)
        self.addCleanup(fake.close)
        fake.delete_status["FAIL11111"] = 409
        env = dict(os.environ, ASC_KEY_ID="KEYID123", ASC_ISSUER_ID="ISSUER-UUID", ASC_KEY_FILE=self.p8,
                   ASC_API_BASE=fake.url)
        env.pop("GITHUB_STEP_SUMMARY", None)
        result = subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 1, output)
        self.assertIn("::error::", output)
        self.assertIn("409", output)
        self.assertEqual(sorted(fake.deletes), ["FAIL11111", "GOOD22222"])
        self.assertEqual([c["id"] for c in fake.certs], ["FAIL11111"])

    def test_10_wrong_signature_is_rejected_and_fails(self):
        _, other_pub = make_key(self.dir, "other")
        result, fake = self.run_script([cert("DEV111111")], pub=other_pub)
        self.assertEqual(result.returncode, 1)
        self.assertIn("401", result.stdout + result.stderr)
        self.assertEqual(fake.deletes, [])

    def test_10b_a_new_valid_token_is_sent_with_every_request(self):
        result, fake = self.run_script([cert("DEV111111")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertGreaterEqual(len(fake.tokens), 3)  # listen, löschen, erneut listen
        self.assertTrue(all(t for t in fake.tokens))

    def test_11_no_secrets_in_output(self):
        body = "".join(l for l in Path(self.p8).read_text().splitlines() if "-----" not in l)
        _, other_pub = make_key(self.dir, "other")
        for label, pub, code in (("ok", None, 0), ("401", other_pub, 1)):
            with self.subTest(case=label):
                certs = [cert("DEV111111")]
                certs[0]["attributes"]["certificateContent"] = "MIICERTCONTENTSECRET"
                result, fake = self.run_script(certs, pub=pub)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, code, output)
                self.assertTrue(fake.tokens, "Skript hat nie ein Token gesendet")
                self.assertNotIn(body, output)
                self.assertNotIn(body[:40], output)
                self.assertNotIn("MIICERTCONTENTSECRET", output)
                for token in fake.tokens:
                    self.assertNotIn(token, output)
                    self.assertNotIn(token.split(".")[2], output)

    def test_missing_environment_exits_1(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("ASC_")}
        result = subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout + result.stderr)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text()
        match = re.search(r"(?m)^  upload:\n((?:(?:    .*)?\n)+)", self.text)
        self.assertIsNotNone(match, "Job upload fehlt in testflight.yml")
        self.upload = match.group(1)

    def step(self, name):
        match = re.search(rf"(?ms)^      - name: {re.escape(name)}\n(.*?)(?=^      - |\Z)", self.upload)
        self.assertIsNotNone(match, f"Schritt {name!r} fehlt im Job upload")
        return match.group(1)

    def test_12_cleanup_steps_sit_in_the_right_order(self):
        names = ["Store the App Store Connect API key", CLEAR_BEFORE, "Archive", "Upload to TestFlight",
                 CLEAR_AFTER, "Remove the key"]
        positions = [self.upload.find(f"- name: {n}\n") for n in names]
        self.assertNotIn(-1, positions, dict(zip(names, positions)))
        self.assertEqual(positions, sorted(positions))
        self.assertRegex(self.step(CLEAR_AFTER), r"(?m)^        if: always\(\)$")
        self.assertNotRegex(self.step(CLEAR_BEFORE), r"(?m)^        if:")
        for name in (CLEAR_BEFORE, CLEAR_AFTER):
            self.assertIn("scripts/asc_cleanup_certs.py", self.step(name))

    def test_12_old_steps_and_confirm_stay(self):
        steps = re.findall(r"(?m)^      - (?:name: (.+)|uses: .+)$", self.upload)
        for name in ("Check the secrets are in place", "Select Xcode 27.0", "Install XcodeGen", "Generate project",
                     "Verify the archive is built against the iOS 27 SDK", "Write export options",
                     "Show what went wrong", "Upload logs"):
            self.assertIn(name, steps)
        confirm = re.search(r"(?m)^  confirm:\n((?:(?:    .*)?\n)+)", self.text)
        self.assertIsNotNone(confirm)
        self.assertRegex(confirm.group(1), r"(?m)^    needs: upload$")
        self.assertIn("scripts/asc_wait_build.py", confirm.group(1))

    def test_12_run_blocks_are_valid_bash(self):
        blocks, current = [], None
        for line in self.text.splitlines():
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
        self.assertGreaterEqual(len(blocks), 10)
        for block in blocks:
            script = re.sub(r"\$\{\{.*?\}\}", "X", block)
            result = subprocess.run(["bash", "-n"], input=script, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr + "\n" + script[:200])

    def test_13_dry_run_input_is_passed_on(self):
        dispatch = re.search(r"(?ms)^  workflow_dispatch:\n(.*?)(?=^  \w|^\w|\Z)", self.text)
        self.assertIsNotNone(dispatch)
        match = re.search(r"(?ms)^      cleanup_dry_run:\n(.*?)(?=^      \w|\Z)", dispatch.group(1))
        self.assertIsNotNone(match, "Eingabe cleanup_dry_run fehlt")
        self.assertRegex(match.group(1), r"(?m)^        type: boolean$")
        self.assertRegex(match.group(1), r"(?m)^        default: false$")
        for name in (CLEAR_BEFORE, CLEAR_AFTER):
            block = self.step(name)
            self.assertIn("inputs.cleanup_dry_run", block)
            self.assertIn("--dry-run", block)

    def test_14_doc_describes_the_way(self):
        text = DOC.read_text()
        for term in ("Created via API", "cleanup_dry_run", "zertifikate vorher", "maximum number of certificates"):
            self.assertIn(term, text)


if __name__ == "__main__":
    unittest.main()
