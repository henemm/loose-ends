"""Tests für asc_beta_setup.py und den Job `setup` in .github/workflows/asc-beta.yml (#705 Schnitt 2a).

Aufruf: python3 scripts/test_asc_beta_setup.py
Gegen einen lokalen Nachbau mit veränderlichem Zustand: er prüft nur die Form (welche Aufrufe, nichts vor der
Validierung, kein Schreiben ohne Abweichung, nichts Persönliches in der Ausgabe). Ob Apple die Werte annimmt und
der Schlüssel schreiben darf, zeigt nur der echte Lauf `aktion=einrichten`.
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

from asc_beta_setup import split_description  # noqa: E402
from asc_wait_build import Fatal  # noqa: E402

SCRIPT = SCRIPTS / "asc_beta_setup.py"
REPO = SCRIPTS.parent
WORKFLOW = REPO / ".github" / "workflows" / "asc-beta.yml"
DESCRIPTION_FILE = REPO / "docs" / "reference" / "beta-beschreibung.md"

CONTACT = {"ASC_REVIEW_FIRST_NAME": "Maxi", "ASC_REVIEW_LAST_NAME": "Beispiel",
           "ASC_REVIEW_PHONE": "+49 170 0000000", "ASC_REVIEW_EMAIL": "kontakt@example.test"}
DESCRIPTION = "Beschreibung-Geheimtext-Beta"
PRIVACY_URL = "https://privacy.example.test/loose-ends"
EMPTY_DETAIL = {"id": "D1", "attributes": {"contactFirstName": None, "contactLastName": None, "contactPhone": None,
                                           "contactEmail": None, "demoAccountRequired": None}}
FULL_DETAIL = {"id": "D1", "attributes": {"contactFirstName": "Maxi", "contactLastName": "Beispiel",
                                          "contactPhone": "+49 170 0000000", "contactEmail": "kontakt@example.test",
                                          "demoAccountRequired": False}}


def localization(lid, description, email):
    return {"id": lid, "attributes": {"locale": "de-DE", "description": description, "feedbackEmail": email,
                                      "privacyPolicyUrl": None}}


class FakeASC:
    """Nachbau mit Zustand: GET liest, POST/PATCH schreiben in den Zustand; jede Anfrage wird gemerkt."""

    def __init__(self, localizations=(), detail=EMPTY_DETAIL, write_status=None):
        self.localizations = [copy.deepcopy(item) for item in localizations]
        self.detail = copy.deepcopy(detail)
        self.write_status = write_status
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
                if fake.write_status:
                    return self.reply(fake.write_status, {"errors": [{"status": str(fake.write_status)}]})
                return self.reply(*fake.write(self.command, self.path, body))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def read(self, path):
        if path.startswith("/v1/apps?"):
            return 200, {"data": [{"id": "APP1"}]}
        if path.startswith("/v1/apps/APP1/betaAppLocalizations"):
            return 200, {"data": self.localizations}
        if path.startswith("/v1/apps/APP1/betaAppReviewDetail"):
            return (200, {"data": self.detail}) if self.detail else (404, {"errors": []})
        return 404, {}

    def write(self, method, path, body):
        attributes = body["data"].get("attributes", {})
        if method == "POST" and path == "/v1/betaAppLocalizations":
            record = {"id": f"L{len(self.localizations) + 1}", "attributes": dict(attributes)}
            self.localizations.append(record)
            return 201, {"data": record}
        for record in [*self.localizations, self.detail]:
            if record and path.endswith(f"/{record['id']}") and method == "PATCH":
                record["attributes"].update(attributes)
                return 200, {"data": record}
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def close(self):
        self.server.shutdown()


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)
        self.description = Path(self.tmp.name) / "beschreibung.md"
        self.description.write_text(f"\n{DESCRIPTION}\n\n")

    def fake(self, **kwargs):
        fake = FakeASC(**kwargs)
        self.addCleanup(fake.close)
        return fake

    def run_setup(self, fake, description=None, drop=(), **extra):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", ASC_PRIVACY_POLICY_URL="",
                   BETA_DESCRIPTION_FILE=str(description or self.description), **CONTACT)
        env.update(extra)
        for name in drop:
            env.pop(name, None)
        return subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=120)

    def test_creates_missing_localization_and_patches_review_detail(self):
        fake = self.fake()
        result = self.run_setup(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        posts = [b for m, p, b in fake.writes() if m == "POST" and p == "/v1/betaAppLocalizations"]
        self.assertEqual(len(posts), 1, fake.writes())
        data = posts[0]["data"]
        self.assertEqual(data["attributes"]["locale"], "de-DE")
        self.assertEqual(data["attributes"]["description"], DESCRIPTION)
        self.assertEqual(data["attributes"]["feedbackEmail"], CONTACT["ASC_REVIEW_EMAIL"])
        self.assertEqual(data["relationships"]["app"]["data"]["id"], "APP1")
        patches = [b for m, p, b in fake.writes() if m == "PATCH" and p == "/v1/betaAppReviewDetails/D1"]
        self.assertEqual(len(patches), 1, fake.writes())
        self.assertEqual(patches[0]["data"]["attributes"], {
            "contactFirstName": "Maxi", "contactLastName": "Beispiel", "contactPhone": "+49 170 0000000",
            "contactEmail": "kontakt@example.test", "demoAccountRequired": False})
        self.assertEqual(len(fake.writes()), 2, fake.writes())

    def test_patches_existing_localization_only_where_different(self):
        fake = self.fake(localizations=[localization("L1", "alt", CONTACT["ASC_REVIEW_EMAIL"])], detail=FULL_DETAIL)
        result = self.run_setup(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/betaAppLocalizations/L1")])
        self.assertEqual(fake.writes()[0][2]["data"]["attributes"], {"description": DESCRIPTION})

    def test_second_run_sends_no_write(self):
        fake = self.fake()
        self.assertEqual(self.run_setup(fake).returncode, 0)
        before = len(fake.requests)
        result = self.run_setup(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({m for m, _, _ in fake.requests[before:]}, {"GET"})
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)

    def test_unchanged_state_writes_nothing(self):
        fake = self.fake(localizations=[localization("L1", DESCRIPTION, CONTACT["ASC_REVIEW_EMAIL"])],
                         detail=FULL_DETAIL)
        result = self.run_setup(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(fake.writes(), [])
        self.assertIn("unverändert", result.stdout)

    def test_privacy_url_only_when_given(self):
        fake = self.fake()
        self.assertEqual(self.run_setup(fake).returncode, 0)
        self.assertNotIn("privacyPolicyUrl", json.dumps([b for _, _, b in fake.writes()]))
        fake = self.fake()
        result = self.run_setup(fake, ASC_PRIVACY_POLICY_URL=PRIVACY_URL)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        post, = [b for m, _, b in fake.writes() if m == "POST"]
        self.assertEqual(post["data"]["attributes"]["privacyPolicyUrl"], PRIVACY_URL)
        self.assertIn("datenschutzUrl=gesetzt", result.stdout)

    def test_missing_secret_aborts_before_any_write(self):
        for name in CONTACT:
            fake = self.fake()
            result = self.run_setup(fake, drop=(name,))
            self.assertEqual(result.returncode, 1, name)
            self.assertIn("::error::", result.stdout)
            self.assertIn(name, result.stdout)
            self.assertEqual(fake.requests, [], name)

    def test_phone_without_plus_aborts_before_any_write(self):
        fake = self.fake()
        result = self.run_setup(fake, ASC_REVIEW_PHONE="0170 0000000")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        self.assertNotIn("0170 0000000", result.stdout + result.stderr)
        self.assertEqual(fake.requests, [])

    def test_forbidden_write_is_reported_clearly(self):
        result = self.run_setup(self.fake(write_status=403))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Schlüssel ohne Schreibrecht", result.stdout)

    def test_output_has_no_values_and_no_key(self):
        result = self.run_setup(self.fake(), ASC_PRIVACY_POLICY_URL=PRIVACY_URL)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = result.stdout + result.stderr
        for secret in (*CONTACT.values(), DESCRIPTION, PRIVACY_URL, "BEGIN", "PRIVATE KEY", "Bearer", "eyJ"):
            self.assertNotIn(secret, output)
        self.assertIn("gesetzt", output)

    def test_ambiguous_or_missing_state_aborts(self):
        two = [localization("L1", "a", None), localization("L2", "b", None)]
        for fake in (self.fake(localizations=two), self.fake(detail=None)):
            result = self.run_setup(fake)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("::error::", result.stdout)
            self.assertEqual(fake.writes(), [])

    def test_description_file_is_sent_verbatim(self):
        sections = split_description(DESCRIPTION_FILE.read_text().strip())
        self.assertEqual(sorted(sections), ["de-DE", "en-US"])
        german, english = sections["de-DE"], sections["en-US"]
        self.assertTrue(german.startswith("Loose Ends nimmt auf"), german[:40])
        self.assertTrue(german.endswith("„Feedback senden“ antippen."), german[-40:])
        self.assertTrue(english.startswith("Loose Ends takes in"), english[:40])
        self.assertNotIn("!", english)
        for text in sections.values():
            self.assertEqual(text.count("\n\n"), 2)
            self.assertLessEqual(len(text), 4000)
        fake = self.fake()
        result = self.run_setup(fake, description=DESCRIPTION_FILE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        posts = {b["data"]["attributes"]["locale"]: b["data"]["attributes"]["description"]
                 for m, _, b in fake.writes() if m == "POST"}
        self.assertEqual(posts, sections)

    def test_description_sections_per_locale(self):
        sections = Path(self.tmp.name) / "sections.md"
        sections.write_text("## de-DE\n\nDeutsch\n\n## en-US\n\nEnglish\n")
        fake = self.fake(localizations=[localization("L1", "alt", CONTACT["ASC_REVIEW_EMAIL"])], detail=FULL_DETAIL)
        result = self.run_setup(fake, description=sections)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        writes = {(m, p): b["data"]["attributes"] for m, p, b in fake.writes()}
        self.assertEqual(writes[("PATCH", "/v1/betaAppLocalizations/L1")], {"description": "Deutsch"})
        self.assertEqual(writes[("POST", "/v1/betaAppLocalizations")]["locale"], "en-US")
        self.assertEqual(writes[("POST", "/v1/betaAppLocalizations")]["description"], "English")
        self.assertIn("locale=en-US", result.stdout)

    def test_file_without_headings_is_german(self):
        self.assertEqual(split_description("Nur Text\n\nzweiter Absatz"), {"de-DE": "Nur Text\n\nzweiter Absatz"})

    def test_heading_of_an_unknown_locale_fails(self):
        with self.assertRaises(Fatal):
            split_description("## fr-FR\n\nTexte")


class WorkflowTests(unittest.TestCase):
    def test_workflow_file(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        for needle in ("aktion:", "- probe", "- einrichten", "scripts/asc_beta_setup.py", "umask 077", "rm -f",
                       "needs: setup", "inputs.aktion == 'einrichten'"):
            self.assertIn(needle, workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", *CONTACT):
            self.assertIn(f"{name}: ${{{{ secrets.{name} }}}}", workflow)
        # einzige Eingabe ist `aktion`: das Repo ist öffentlich, Eingaben stehen sichtbar in der Laufansicht
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))
        self.assertNotIn("asc_beta_setup", (WORKFLOW.parent / "testflight.yml").read_text())


if __name__ == "__main__":
    unittest.main()
