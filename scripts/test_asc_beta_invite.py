"""Tests für asc_beta_invite.py und den Job `assign` in .github/workflows/asc-beta.yml (#705 Schnitt 2b-1).

Aufruf: python3 scripts/test_asc_beta_invite.py
Gegen einen lokalen Nachbau mit Zustand: er prüft nur die Form (welche Aufrufe, nichts vor der Gruppenprüfung, kein
Schreiben ohne Abweichung, nie Einreichung oder Link). Ob Apple Gruppe und Zuordnung annimmt, zeigt nur der echte Lauf
`aktion=zuordnen`.
"""
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_beta_invite.py"
WORKFLOWS = SCRIPTS.parent / ".github" / "workflows"
WORKFLOW = WORKFLOWS / "asc-beta.yml"

LINK = "https://testflight.apple.com/join/QWERTZ"
BUILDS = {"IOS": {"id": "B-91f3-IOS", "version": "4711"}, "MAC_OS": {"id": "B-91f3-MAC", "version": "4712"}}
WANTED_QUERY = {"filter[app]": ["APP1"], "filter[processingState]": ["VALID"], "filter[expired]": ["false"],
                "sort": ["-uploadedDate"], "limit": ["1"]}


def group(gid, name="Tester", internal=False):
    return {"id": gid, "attributes": {"name": name, "isInternalGroup": internal, "publicLinkEnabled": False}}


class FakeASC:
    """GET liest den Zustand, POST schreibt hinein; jede Anfrage wird mit Methode, Pfad und Rumpf gemerkt."""

    def __init__(self, groups=(), builds=BUILDS, assigned=None, fail=None, fail_get=None):
        self.groups = [json.loads(json.dumps(item)) for item in groups]
        self.builds = dict(builds)
        self.assigned = {gid: set(ids) for gid, ids in (assigned or {}).items()}
        self.fail = fail or (lambda method, path, body: None)
        self.fail_get = fail_get or (lambda path: None)
        self.requests = []
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = b"" if status == 204 else json.dumps(body or {}).encode()
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
                    status = fake.fail_get(self.path)
                    return self.reply(status, {}) if status else self.reply(*fake.read(self.path))
                status = fake.fail(self.command, self.path, body)
                if status:
                    return self.reply(status, {"errors": [{"status": str(status)}]})
                return self.reply(*fake.write(self.command, self.path, body))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def read(self, path):
        route, _, query = path.partition("?")
        if route == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if route == "/v1/apps/APP1/betaGroups":
            return 200, {"data": self.groups}
        if route == "/v1/builds":
            params = urllib.parse.parse_qs(query)
            platform = params.pop("filter[preReleaseVersion.platform]", [""])[0]
            hit = self.builds.get(platform) if params == WANTED_QUERY else None
            return 200, {"data": [{"id": hit["id"], "attributes": {"version": hit["version"]}}] if hit else []}
        for build in self.builds.values():
            if route == f"/v1/builds/{build['id']}/betaGroups":
                return 200, {"data": [g for g in self.groups if build["id"] in self.assigned.get(g["id"], ())]}
            if route == f"/v1/builds/{build['id']}/buildBetaDetail":
                return 200, {"data": {"id": "BD", "attributes": {"externalBuildState": "READY_FOR_BETA_SUBMISSION"}}}
        return 404, {}

    def write(self, method, path, body):
        if method == "POST" and path == "/v1/betaGroups":
            record = {"id": f"G-7c41-{len(self.groups) + 1}", "attributes": dict(body["data"]["attributes"])}
            self.groups.append(record)
            return 201, {"data": record}
        for g in self.groups:
            if method == "POST" and path == f"/v1/betaGroups/{g['id']}/relationships/builds":
                self.assigned.setdefault(g["id"], set()).update(item["id"] for item in body["data"])
                return 204, None
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def close(self):
        self.server.shutdown()


class InviteTests(unittest.TestCase):
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

    def invite(self, fake):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", ASC_PLATFORM="")
        return subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True, timeout=120)

    def assert_clean(self, fake):
        for method, path, body in fake.requests:
            sent = json.dumps(body or {})
            self.assertNotIn("betaAppReviewSubmissions", path)
            self.assertNotIn(method, ("PATCH", "DELETE"), path)
            self.assertNotIn('"publicLinkEnabled": true', sent)
            self.assertNotIn("publicLinkLimit", sent)

    def test_first_run_creates_group_and_assigns_both_platforms(self):
        fake = self.fake()
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        created, *assignments = fake.writes()
        self.assertEqual(created[:2], ("POST", "/v1/betaGroups"))
        self.assertEqual(created[2]["data"]["attributes"], {"name": "Tester", "isInternalGroup": False,
                                                            "feedbackEnabled": True, "publicLinkEnabled": False})
        self.assertEqual(created[2]["data"]["relationships"]["app"]["data"]["id"], "APP1")
        self.assertEqual([(m, p, b["data"]) for m, p, b in assignments], [
            ("POST", "/v1/betaGroups/G-7c41-1/relationships/builds", [{"type": "builds", "id": BUILDS[p]["id"]}])
            for p in ("IOS", "MAC_OS")])
        self.assertIn("gruppe name=Tester zustand=angelegt", result.stdout)
        for platform in ("IOS", "MAC_OS"):
            self.assertIn(f"zuordnung plattform={platform} zustand=gesetzt extern=READY_FOR_BETA_SUBMISSION",
                          result.stdout)
        self.assertIn("zusammenfassung geschrieben=3", result.stdout)

    def test_second_run_sends_no_write(self):
        fake = self.fake()
        self.assertEqual(self.invite(fake).returncode, 0)
        before = len(fake.requests)
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({m for m, _, _ in fake.requests[before:]}, {"GET"})
        self.assertIn("gruppe name=Tester zustand=vorhanden", result.stdout)
        for platform in ("IOS", "MAC_OS"):
            self.assertIn(f"zuordnung plattform={platform} zustand=vorhanden", result.stdout)
        self.assertIn("zusammenfassung geschrieben=0", result.stdout)

    def test_existing_group_only_assigns_missing_build(self):
        fake = self.fake(groups=[group("G-7c41-1")], assigned={"G-7c41-1": {BUILDS["IOS"]["id"]}})
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([(m, p, b["data"]) for m, p, b in fake.writes()], [
            ("POST", "/v1/betaGroups/G-7c41-1/relationships/builds", [{"type": "builds", "id": BUILDS["MAC_OS"]["id"]}])])
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)

    def test_newest_valid_build_is_chosen_per_platform(self):
        fake = self.fake()
        self.assertEqual(self.invite(fake).returncode, 0)
        queries = [urllib.parse.parse_qs(p.partition("?")[2]) for m, p, _ in fake.requests if p.startswith("/v1/builds?")]
        self.assertEqual(queries, [{**WANTED_QUERY, "filter[preReleaseVersion.platform]": [p]} for p in ("IOS", "MAC_OS")])
        self.assertEqual(fake.assigned["G-7c41-1"], {BUILDS["IOS"]["id"], BUILDS["MAC_OS"]["id"]})

    def test_platform_without_valid_build_is_reported_not_failed(self):
        fake = self.fake(builds={"IOS": BUILDS["IOS"]})
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("zuordnung plattform=MAC_OS zustand=kein-gültiger-build", result.stdout)
        self.assertEqual(fake.assigned["G-7c41-1"], {BUILDS["IOS"]["id"]})
        self.assertEqual(len(fake.writes()), 2, fake.writes())

    def test_one_platform_failing_does_not_hide_the_other(self):
        ios = BUILDS["IOS"]["id"]
        fake = self.fake(fail=lambda m, p, b: 422 if p.endswith("/relationships/builds") and ios in json.dumps(b) else None)
        result = self.invite(fake)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue(any(l.startswith("::error::") and "platform=IOS" in l for l in result.stdout.splitlines()))
        self.assertEqual(fake.assigned["G-7c41-1"], {BUILDS["MAC_OS"]["id"]})
        self.assertTrue(result.stdout.strip().splitlines()[-1].startswith("zusammenfassung geschrieben="))

    def test_never_submits_and_never_enables_link(self):
        ios = BUILDS["IOS"]["id"]
        fakes = [self.fake(), self.fake(groups=[group("G-7c41-1")], assigned={"G-7c41-1": {ios}}),
                 self.fake(fail=lambda m, p, b: 422 if ios in json.dumps(b) else None)]
        fakes.append(fakes[0])
        for fake in fakes:
            self.invite(fake)
            self.assert_clean(fake)
        self.assertTrue(all(fake.writes() for fake in fakes), "jedes Szenario muss schreiben, sonst prüft es nichts")

    def test_duplicate_external_groups_abort_before_any_write(self):
        fake = self.fake(groups=[group("G-7c41-1"), group("G-7c41-2")])
        result = self.invite(fake)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)
        self.assertEqual(fake.writes(), [])
        both = {BUILDS["IOS"]["id"], BUILDS["MAC_OS"]["id"]}
        fake = self.fake(groups=[group("G-7c41-1", internal=True), group("G-7c41-2")], assigned={"G-7c41-2": both})
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(fake.writes(), [])

    def test_forbidden_write_is_reported_clearly(self):
        result = self.invite(self.fake(fail=lambda m, p, b: 403))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Schlüssel ohne Schreibrecht", result.stdout)

    def test_output_has_only_state_words(self):
        other = {"id": "G-7c41-9", "attributes": {"name": "Familie", "isInternalGroup": True, "publicLink": LINK}}
        result = self.invite(self.fake(groups=[other]))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = result.stdout + result.stderr
        for secret in ("G-7c41", "B-91f3", "4711", "4712", "APP1", LINK, "BEGIN", "PRIVATE KEY", "Bearer", "eyJ"):
            self.assertNotIn(secret, output)
        for word in ("name=Tester", "plattform=", "zustand=", "extern=", "geschrieben="):
            self.assertIn(word, output)

    def test_unreadable_beta_detail_keeps_the_count(self):
        result = self.invite(self.fake(fail_get=lambda p: 404 if p.endswith("/buildBetaDetail") else None))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for platform in ("IOS", "MAC_OS"):
            self.assertIn(f"zuordnung plattform={platform} zustand=gesetzt extern=unbekannt", result.stdout)
        self.assertIn("zusammenfassung geschrieben=3", result.stdout)

    def test_retry_lines_carry_no_ids(self):
        seen = []
        def once(path):
            hit = path.endswith("/betaGroups") and path.startswith("/v1/builds/") and not seen
            return seen.append(path) or 503 if hit else None
        fake = self.fake(fail_get=once)
        result = self.invite(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(seen and "retrying" in result.stdout, result.stdout)
        self.assertEqual(fake.assigned["G-7c41-1"], {BUILDS["IOS"]["id"], BUILDS["MAC_OS"]["id"]})
        for secret in ("B-91f3", "G-7c41", "APP1"):
            self.assertNotIn(secret, result.stdout + result.stderr)

    def test_message_masks_query_values_only(self):
        from asc_beta_invite import message
        self.assertEqual(message("GET /v1/builds?filter[app]=APP1&limit=1 failed"),
                         "GET /v1/builds?filter[app]=…&limit=… failed")
        line = "zuordnung plattform=IOS zustand=gesetzt extern=unbekannt"
        self.assertEqual(message(line), line)


class WorkflowTests(unittest.TestCase):
    def test_workflow_file(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        for needle in ("- probe", "- einrichten", "- zuordnen", "default: probe", "inputs.aktion == 'zuordnen'",
                       "needs: [setup, assign]", "needs.assign.result"):
            self.assertIn(needle, workflow)
        assign = workflow.split("\n  assign:", 1)[1].split("\n  probe:", 1)[0]
        for needle in ("scripts/asc_beta_invite.py", "umask 077", "rm -f", "runs-on: ubuntu-latest"):
            self.assertIn(needle, assign)
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))
        for forbidden in ("betaAppReviewSubmissions", "publicLinkEnabled"):
            self.assertNotIn(forbidden, workflow)
        self.assertNotIn("asc_beta_invite", (WORKFLOWS / "testflight.yml").read_text())


if __name__ == "__main__":
    unittest.main()
