"""Tests für asc_beta_probe.py und .github/workflows/asc-beta.yml (#705 Schnitt 1).

Aufruf: python3 scripts/test_asc_beta_probe.py
Gegen einen lokalen Nachbau der App-Store-Connect-API: er prüft nur die Form (welche Pfade, nur GET,
Befund statt Fehler, nichts Persönliches in der Ausgabe). Apples echte Antworten zeigt nur der echte Lauf.
Format der Review-Detail-Zeile: `reviewdetail attribute=<Namen> <Name>=gesetzt|leer …`.
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
SCRIPT = SCRIPTS / "asc_beta_probe.py"
WORKFLOWS = SCRIPTS.parent / ".github" / "workflows"
WORKFLOW = WORKFLOWS / "asc-beta.yml"

CONTACT_VALUES = ("Maxi Beispiel", "+49 170 0000000", "kontakt@example.test")
DESCRIPTION = "Beschreibung-Geheimtext-Beta"
PRIVACY_URL = "https://privacy.example.test/loose-ends"
GROUP_LINK = "https://testflight.apple.com/join/ABCDEF"

GROUPS = {"data": [
    {"id": "G1", "attributes": {"name": "Familie", "isInternalGroup": True, "publicLinkEnabled": False,
                                "feedbackEnabled": True}},
    {"id": "G2", "attributes": {"name": "Einladung", "isInternalGroup": False, "publicLinkEnabled": True,
                                "publicLink": GROUP_LINK, "feedbackEnabled": True}}]}
LOCALIZATIONS = {"data": [{"id": "L1", "attributes": {
    "locale": "de-DE", "description": DESCRIPTION, "feedbackEmail": CONTACT_VALUES[2],
    "privacyPolicyUrl": PRIVACY_URL}}]}
LOCALIZATIONS_EMPTY = {"data": [{"id": "L1", "attributes": {
    "locale": "de-DE", "description": "", "feedbackEmail": None, "privacyPolicyUrl": None}}]}
REVIEW_DETAIL = {"data": {"id": "D1", "attributes": {
    "contactFirstName": "Maxi", "contactLastName": "Beispiel", "contactPhone": CONTACT_VALUES[1],
    "contactEmail": CONTACT_VALUES[2], "demoAccountName": "", "demoAccountRequired": False}}}
BETA_DETAIL = {"data": {"id": "BD", "attributes": {
    "internalBuildState": "IN_BETA_TESTING", "externalBuildState": "READY_FOR_BETA_SUBMISSION"}}}


def build(number, platform="IOS"):
    return {"id": f"B{number}-{platform}", "attributes": {
        "version": number, "processingState": "VALID", "platform": platform}}


def default_routes():
    return {
        "/v1/apps?": (200, {"data": [{"id": "APP1"}]}),
        "/v1/apps/APP1/betaGroups": (200, GROUPS),
        "/v1/apps/APP1/betaAppReviewDetail": (200, REVIEW_DETAIL),
        "/v1/apps/APP1/betaAppLocalizations": (200, LOCALIZATIONS),
        "/v1/builds?": (200, {"data": [build("42")]}),
        "/v1/builds/B42-IOS/buildBetaDetail": (200, BETA_DETAIL),
        "/v1/builds/B42-IOS/betaAppReviewSubmission": (200, {"data": None}),
        "/v1/betaAppReviewSubmissions?": (200, {"data": [
            {"id": "S1", "attributes": {"betaReviewState": "WAITING_FOR_REVIEW"}}]}),
    }


class FakeASC:
    """Antwortet je Pfad-Anfang mit (Status, Rumpf); merkt sich jede Anfrage mit Methode."""

    def __init__(self, routes=None, status_for=None, truncated=()):
        self.routes = dict(default_routes() if routes is None else routes)
        self.status_for = status_for  # (Status, Rumpf) für alles außer der App-Suche
        self.truncated = truncated  # Pfad-Anfänge, deren Antwort mitten im Rumpf abbricht
        self.requests = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = json.dumps(body if body is not None else {}).encode()
                cut = any(self.path.startswith(prefix) for prefix in fake.truncated)
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw) + (100 if cut else 0)))
                self.end_headers()
                self.wfile.write(raw)

            def handle_any(self):
                fake.requests.append((self.command, self.path))
                if self.command != "GET":
                    return self.reply(405)
                if self.path.startswith("/v1/apps?"):
                    status, body = fake.routes.get("/v1/apps?", (200, {"data": [{"id": "APP1"}]}))
                    return self.reply(status, body)
                if fake.status_for is not None:
                    return self.reply(*fake.status_for)
                # längster passender Pfad-Anfang gewinnt
                matches = [key for key in fake.routes if self.path.startswith(key)]
                if not matches:
                    return self.reply(404)
                return self.reply(*fake.routes[max(matches, key=len)])

            do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def close(self):
        self.server.shutdown()


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def probe(self, fake, platform="", drop=()):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key),
                   ASC_API_BASE=fake.base if fake else "http://127.0.0.1:9", ASC_POLL_SECONDS="0",
                   ASC_TIMEOUT_SECONDS="2", ASC_PLATFORM=platform)
        for name in drop:
            env.pop(name, None)
        return subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=120)

    def fake(self, **kwargs):
        fake = FakeASC(**kwargs)
        self.addCleanup(fake.close)
        return fake

    @staticmethod
    def lines(result, prefix):
        return [line for line in result.stdout.splitlines() if line.startswith(prefix)]

    def test_everything_present(self):
        result = self.probe(self.fake())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        access = self.lines(result, "zugriff")
        for name in ("betaGroups", "betaAppReviewDetail", "betaAppLocalizations", "builds",
                     "buildBetaDetail", "betaAppReviewSubmissions"):
            self.assertTrue(any(f"abfrage={name}" in line and "http=200" in line for line in access),
                            f"{name}: {access}")
        groups = self.lines(result, "gruppe")
        self.assertTrue(any("intern=ja" in line for line in groups), groups)
        external = [line for line in groups if "intern=nein" in line]
        self.assertTrue(external and "link=an" in external[0] and "url=gesetzt" in external[0]
                        and "feedback=an" in external[0], groups)
        self.assertTrue(any("beschreibung=gesetzt" in line for line in self.lines(result, "lokalisierung")),
                        result.stdout)
        detail = "\n".join(self.lines(result, "reviewdetail"))
        self.assertIn("attribute=", detail)
        for name in ("contactFirstName", "contactPhone", "demoAccountName"):
            self.assertIn(name, detail)
        self.assertIn("contactFirstName=gesetzt", detail)
        self.assertIn("demoAccountName=leer", detail)
        self.assertIn("demoAccountRequired=aus", detail)
        build_line, = self.lines(result, "build nummer=42")
        for part in ("processingState=VALID", "intern=IN_BETA_TESTING", "extern=READY_FOR_BETA_SUBMISSION"):
            self.assertIn(part, build_line)
        self.assertTrue(any(line.startswith("einreichung build=42") for line in result.stdout.splitlines()),
                        result.stdout)
        self.assertEqual(len(self.lines(result, "zusammenfassung")), 1, result.stdout)

    def test_forbidden_on_groups_is_a_finding(self):
        routes = default_routes()
        routes["/v1/apps/APP1/betaGroups"] = (403, {"errors": [{"code": "FORBIDDEN"}]})
        result = self.probe(self.fake(routes=routes))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        line, = [l for l in self.lines(result, "zugriff") if "abfrage=betaGroups" in l]
        self.assertIn("http=403", line)
        self.assertIn("befund=", line)
        self.assertTrue(self.lines(result, "reviewdetail"), result.stdout)
        self.assertTrue(self.lines(result, "build nummer="), result.stdout)

    def test_broken_answer_on_groups_is_a_finding(self):
        result = self.probe(self.fake(truncated=("/v1/apps/APP1/betaGroups",)))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        line, = [l for l in self.lines(result, "zugriff") if "abfrage=betaGroups" in l]
        self.assertIn("http=keine", line)
        self.assertIn("befund=", line)
        self.assertTrue(self.lines(result, "reviewdetail"), result.stdout)
        self.assertTrue(self.lines(result, "build nummer="), result.stdout)

    def test_empty_description_is_reported_as_empty(self):
        routes = default_routes()
        routes["/v1/apps/APP1/betaAppLocalizations"] = (200, LOCALIZATIONS_EMPTY)
        result = self.probe(self.fake(routes=routes))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        line, = self.lines(result, "lokalisierung")
        self.assertIn("beschreibung=leer", line)
        self.assertIn("feedbackEmail=leer", line)
        self.assertIn("datenschutzUrl=leer", line)

    def test_no_group(self):
        routes = default_routes()
        routes["/v1/apps/APP1/betaGroups"] = (200, {"data": []})
        result = self.probe(self.fake(routes=routes))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("gruppe keine", result.stdout)
        self.assertEqual(self.lines(result, "gruppe name="), [])

    def test_both_platforms(self):
        for platform, other in (("IOS", "MAC_OS"), ("MAC_OS", "IOS")):
            routes = default_routes()
            routes["/v1/builds?"] = (200, {"data": [build("42", platform)]})
            routes[f"/v1/builds/B42-{platform}/buildBetaDetail"] = (200, BETA_DETAIL)
            fake = self.fake(routes=routes)
            result = self.probe(fake, platform=platform)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(f"plattform={platform}", result.stdout)
            self.assertNotIn(f"plattform={other}", result.stdout)
            builds = [path for method, path in fake.requests if path.startswith("/v1/builds?")]
            self.assertTrue(builds and all(f"filter[preReleaseVersion.platform]={platform}" in p for p in builds),
                            builds)

    def test_only_get_requests(self):
        fake = self.fake()
        self.probe(fake)
        self.probe(fake, platform="MAC_OS")
        self.assertTrue(fake.requests)
        self.assertEqual({method for method, _ in fake.requests}, {"GET"})

    def test_output_has_no_contact_values_and_no_key(self):
        result = self.probe(self.fake())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = result.stdout + result.stderr
        for secret in (*CONTACT_VALUES, DESCRIPTION, PRIVACY_URL, GROUP_LINK, "BEGIN", "PRIVATE KEY", "Bearer", "eyJ"):
            self.assertNotIn(secret, output)
        self.assertIn("gesetzt", output)

    def test_link_off_prints_dash_and_never_the_link(self):
        routes = default_routes()
        routes["/v1/apps/APP1/betaGroups"] = (200, {"data": [
            {"id": "G2", "attributes": {"name": "Einladung", "isInternalGroup": False, "publicLinkEnabled": False,
                                        "publicLink": GROUP_LINK, "feedbackEnabled": True}}]})
        result = self.probe(self.fake(routes=routes))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        group, = self.lines(result, "gruppe name=")
        self.assertIn("link=aus", group)
        self.assertIn("url=-", group)
        self.assertNotIn(GROUP_LINK, result.stdout + result.stderr)

    def test_nothing_answers_exits_1(self):
        result = self.probe(self.fake(status_for=(500, {})))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    def test_all_404_is_findings_exit_0(self):
        result = self.probe(self.fake(status_for=(404, {})))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        access = self.lines(result, "zugriff")
        self.assertTrue(access)
        for line in access:
            self.assertIn("http=404", line)
            self.assertIn("befund=", line)

    def test_app_not_found_exits_1(self):
        routes = default_routes()
        routes["/v1/apps?"] = (200, {"data": []})
        result = self.probe(self.fake(routes=routes))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    def test_missing_environment_exits_1(self):
        result = self.probe(self.fake(), drop=("ASC_KEY_ID",))
        self.assertEqual(result.returncode, 1)
        self.assertIn("Missing environment", result.stdout)


class WorkflowTests(unittest.TestCase):
    def test_workflow_file(self):
        self.assertTrue(WORKFLOW.exists(), f"{WORKFLOW} fehlt")
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        for needle in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY", "platform: [IOS, MAC_OS]",
                       "ASC_PLATFORM: ${{ matrix.platform }}", "runs-on: ubuntu-latest",
                       "scripts/asc_beta_probe.py", "umask 077", "rm -f", 'ASC_POLL_SECONDS: "5"'):
            self.assertIn(needle, workflow)
        self.assertNotIn("asc_beta_probe", (WORKFLOWS / "testflight.yml").read_text())


if __name__ == "__main__":
    unittest.main()
