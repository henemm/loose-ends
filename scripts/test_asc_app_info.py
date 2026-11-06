"""Tests für asc_app_info.py und .github/workflows/asc-app-info.yml (#837 Schnitt 2).

Aufruf: python3 scripts/test_asc_app_info.py
Gegen einen lokalen Nachbau mit veränderlichem Zustand: er prüft nur die Form (welche App-Info gewählt wird, welche
Aufrufe hinausgehen, nichts vor der Prüfung des Textes, kein Schreiben ohne Abweichung, keine Zugangsdaten in der
Ausgabe). Ob Apple den PATCH-Umschlag annimmt, zeigt nur der echte Lauf `aktion=untertitel` (AC-9).
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

SCRIPT = SCRIPTS / "asc_app_info.py"
REPO = SCRIPTS.parent
WORKFLOW = REPO / ".github" / "workflows" / "asc-app-info.yml"
TEXT_FILE = REPO / "docs" / "reference" / "app-store-untertitel.md"

DE_WANTED = "Einfach sagen. Kopf frei."
EN_WANTED = "Say it. Clear your head."
NAME = "Loose Ends"
DE_OLD = "Gesagt. Sortiert."
RAW_SECRET = "Roh-Antwort-Geheim-837"
WANTED_TEXT = f"# Untertitel\n\nVorspann.\n\n## de-DE\n\nUntertitel: {DE_WANTED}\n\n## en-US\n\nName: {NAME}\nUntertitel: {EN_WANTED}\n"


def info(info_id, state):
    return {"id": info_id, "type": "appInfos", "attributes": {"state": state, "appStoreState": state}}


def loc(loc_id, locale, subtitle, name=NAME):
    return {"id": loc_id, "type": "appInfoLocalizations",
            "attributes": {"locale": locale, "name": name, "subtitle": subtitle}}


class FakeASC:
    """Nachbau mit Zustand: GET liest, PATCH/POST schreiben in den Zustand; jede Anfrage wird gemerkt."""

    def __init__(self, infos, localizations=None, write_status=None, ignore_writes=False, error_code=None):
        self.infos = [copy.deepcopy(item) for item in infos]
        self.localizations = {key: [copy.deepcopy(item) for item in value]
                              for key, value in (localizations or {}).items()}
        self.write_status = write_status
        self.error_code = error_code
        self.ignore_writes = ignore_writes
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
                    return self.reply(fake.write_status,
                                      {"errors": [{"status": str(fake.write_status), "detail": RAW_SECRET,
                                                   **({"code": fake.error_code} if fake.error_code else {})}]})
                return self.reply(*fake.write(self.command, self.path, body))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def read(self, path):
        url = path.split("?")[0]
        if url == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if url == "/v1/apps/APP1/appInfos":
            return 200, {"data": self.infos}
        for item in self.infos:
            if url == f"/v1/appInfos/{item['id']}/appInfoLocalizations":
                return 200, {"data": self.localizations.get(item["id"], [])}
        return 404, {}

    def write(self, method, path, body):
        if self.ignore_writes:
            return 200, {"data": {}}
        data = body["data"]
        if method == "PATCH" and path.startswith("/v1/appInfoLocalizations/"):
            for items in self.localizations.values():
                for item in items:
                    if path == f"/v1/appInfoLocalizations/{item['id']}":
                        item["attributes"].update(data.get("attributes", {}))
                        return 200, {"data": item}
        if method == "POST" and path == "/v1/appInfoLocalizations":
            info_id = data["relationships"]["appInfo"]["data"]["id"]
            created = {"id": f"NEW-{data['attributes']['locale']}", "type": "appInfoLocalizations",
                       "attributes": dict(data["attributes"])}
            self.localizations.setdefault(info_id, []).append(created)
            return 201, {"data": created}
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def close(self):
        self.server.shutdown()


EDITABLE = info("I2", "PREPARE_FOR_SUBMISSION")
LIVE = info("I1", "READY_FOR_DISTRIBUTION")


class AppInfoTests(unittest.TestCase):
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

    def run_info(self, fake, aktion, text=WANTED_TEXT):
        path = Path(self.tmp.name) / "untertitel.md"
        path.write_text(text, encoding="utf-8")
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", APP_INFO_FILE=str(path))
        return subprocess.run([sys.executable, str(SCRIPT), aktion], env=env, capture_output=True, text=True,
                              timeout=120)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    def both_equal(self):
        return {"I1": [loc("L1", "de-DE", DE_OLD)],
                "I2": [loc("L2", "de-DE", DE_WANTED), loc("L3", "en-US", EN_WANTED)]}

    # AC-1
    def test_locked_appinfos_abort_with_zero_writes(self):
        fake = self.fake(infos=[LIVE, info("I2", "IN_REVIEW")],
                         localizations={"I1": [loc("L1", "de-DE", DE_OLD)], "I2": [loc("L2", "de-DE", DE_OLD)]})
        result = self.run_info(fake, "untertitel")
        self.assert_failed(result)
        self.assertIn("App-Informationen gesperrt", result.stdout)
        self.assertIn("READY_FOR_DISTRIBUTION", result.stdout)
        self.assertIn("IN_REVIEW", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-2
    def test_several_editable_appinfos_abort(self):
        fake = self.fake(infos=[info("I1", "PREPARE_FOR_SUBMISSION"), EDITABLE],
                         localizations={"I1": [loc("L1", "de-DE", DE_OLD)], "I2": [loc("L2", "de-DE", DE_OLD)]})
        result = self.run_info(fake, "untertitel")
        self.assert_failed(result)
        self.assertIn("mehrdeutig", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-3
    def test_equal_values_write_nothing(self):
        fake = self.fake(infos=[LIVE, EDITABLE], localizations=self.both_equal())
        result = self.run_info(fake, "untertitel")
        self.assert_ok(result)
        self.assertEqual(fake.writes(), [])
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=0"), result.stdout)

    # AC-4
    def test_different_subtitle_patches_once_with_subtitle_only(self):
        localizations = self.both_equal()
        localizations["I2"][0] = loc("L2", "de-DE", DE_OLD)
        fake = self.fake(infos=[LIVE, EDITABLE], localizations=localizations)
        result = self.run_info(fake, "untertitel")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appInfoLocalizations/L2")])
        data = fake.writes()[0][2]["data"]
        self.assertEqual(data["type"], "appInfoLocalizations")
        self.assertEqual(data["id"], "L2")
        self.assertEqual(data["attributes"], {"subtitle": DE_WANTED})
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)
        self.assertEqual(fake.localizations["I1"][0]["attributes"]["subtitle"], DE_OLD)

    # AC-5
    def test_missing_en_us_posts_once_with_locale_name_subtitle_and_appinfo(self):
        fake = self.fake(infos=[LIVE, EDITABLE],
                         localizations={"I1": [loc("L1", "de-DE", DE_OLD)], "I2": [loc("L2", "de-DE", DE_WANTED)]})
        result = self.run_info(fake, "untertitel")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("POST", "/v1/appInfoLocalizations")])
        data = fake.writes()[0][2]["data"]
        self.assertEqual(data["type"], "appInfoLocalizations")
        self.assertEqual(data["attributes"], {"locale": "en-US", "name": NAME, "subtitle": EN_WANTED})
        self.assertEqual(data["relationships"]["appInfo"]["data"], {"type": "appInfos", "id": "I2"})
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)

    # AC-6
    def test_too_long_text_aborts_before_any_request(self):
        for text in (WANTED_TEXT.replace(DE_WANTED, "x" * 31),
                     WANTED_TEXT.replace(f"Name: {NAME}", "Name: " + "n" * 31)):
            fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD)]})
            result = self.run_info(fake, "untertitel", text=text)
            self.assert_failed(result)
            self.assertIn("31", result.stdout)
            self.assertIn("30", result.stdout)
            self.assertEqual(fake.requests, [])

    def test_missing_section_aborts_before_any_request(self):
        fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD)]})
        result = self.run_info(fake, "untertitel", text=WANTED_TEXT.split("## en-US")[0])
        self.assert_failed(result)
        self.assertIn("en-US", result.stdout)
        self.assertEqual(fake.requests, [])

    # AC-7
    def test_403_and_409_give_clear_message(self):
        for status, word in ((403, "gesperrt"), (409, "Konflikt")):
            fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD),
                                                                       loc("L3", "en-US", EN_WANTED)]},
                             write_status=status)
            result = self.run_info(fake, "untertitel")
            self.assert_failed(result)
            self.assertIn(word, result.stdout)
            self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)
            self.assertNotIn("zusammenfassung geschrieben", result.stdout)

    # AC-4
    def test_409_message_keeps_code(self):
        fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD),
                                                                   loc("L3", "en-US", EN_WANTED)]},
                         write_status=409, error_code="ENTITY_ERROR.RELATIONSHIP.INVALID")
        result = self.run_info(fake, "untertitel")
        self.assert_failed(result)
        self.assertIn("Konflikt", result.stdout)
        self.assertIn("ENTITY_ERROR.RELATIONSHIP.INVALID", result.stdout)
        self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)

    def test_403_message_unchanged(self):
        fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD),
                                                                   loc("L3", "en-US", EN_WANTED)]},
                         write_status=403, error_code="FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED")
        result = self.run_info(fake, "untertitel")
        self.assert_failed(result)
        self.assertIn("gesperrt", result.stdout)
        self.assertNotIn("FORBIDDEN.REQUIRED", result.stdout)

    def test_verification_mismatch_is_error(self):
        fake = self.fake(infos=[EDITABLE], localizations={"I2": [loc("L2", "de-DE", DE_OLD),
                                                                   loc("L3", "en-US", EN_WANTED)]},
                         ignore_writes=True)
        result = self.run_info(fake, "untertitel")
        self.assert_failed(result)
        self.assertIn("Gegenprobe", result.stdout)
        self.assertEqual(len(fake.writes()), 1, fake.writes())

    # AC-8
    def test_lesen_never_writes_and_prints_values(self):
        fake = self.fake(infos=[LIVE, info("I2", "IN_REVIEW")],
                         localizations={"I1": [loc("L1", "de-DE", DE_OLD)],
                                        "I2": [loc("L2", "de-DE", DE_OLD), loc("L3", "en-US", EN_WANTED)]})
        result = self.run_info(fake, "lesen", text="kaputt, wird für lesen nicht gebraucht")
        self.assert_ok(result)
        self.assertEqual([m for m, _, _ in fake.requests if m != "GET"], [])
        for needle in ("READY_FOR_DISTRIBUTION", "IN_REVIEW", DE_OLD, EN_WANTED, NAME, "de-DE", "en-US"):
            self.assertIn(needle, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=0"), result.stdout)

    def test_output_has_no_secrets(self):
        key_body = "".join(self.key.read_text().splitlines()[1:-1])
        secrets = (key_body, "BEGIN", "PRIVATE KEY", "Bearer", "eyJ", RAW_SECRET)
        loc_two = {"I2": [loc("L2", "de-DE", DE_OLD), loc("L3", "en-US", EN_WANTED)]}
        runs = [(self.fake(infos=[LIVE, info("I2", "IN_REVIEW")], localizations=loc_two), "untertitel", WANTED_TEXT),
                (self.fake(infos=[EDITABLE], localizations=loc_two, write_status=403), "untertitel", WANTED_TEXT),
                (self.fake(infos=[EDITABLE], localizations=loc_two, write_status=409), "untertitel", WANTED_TEXT),
                (self.fake(infos=[EDITABLE], localizations=loc_two, ignore_writes=True), "untertitel", WANTED_TEXT),
                (self.fake(infos=[EDITABLE], localizations=loc_two), "lesen", WANTED_TEXT)]
        for fake, aktion, text in runs:
            result = self.run_info(fake, aktion, text=text)
            output = result.stdout + result.stderr
            self.assertTrue("::error::" in result.stdout or "zusammenfassung geschrieben=" in result.stdout, output)
            for secret in secrets:
                self.assertNotIn(secret, output, (aktion, secret))

    def test_unknown_action_aborts_before_any_request(self):
        fake = self.fake(infos=[EDITABLE])
        result = self.run_info(fake, "einreichen")
        self.assert_failed(result)
        self.assertEqual(fake.requests, [])


class TextFileTests(unittest.TestCase):
    # AC-8
    def test_repo_text_file_parses_and_fits_limit(self):
        from asc_app_info import MAX_CHARS, wanted_texts
        wanted = wanted_texts(TEXT_FILE.read_text(encoding="utf-8"))
        self.assertEqual(MAX_CHARS, 30)
        self.assertEqual(wanted["de-DE"]["subtitle"], DE_WANTED)
        self.assertEqual(wanted["en-US"]["subtitle"], EN_WANTED)
        self.assertEqual(wanted["en-US"]["name"], NAME)
        for values in wanted.values():
            for value in values.values():
                self.assertLessEqual(len(value), 30, value)


class WorkflowTests(unittest.TestCase):
    def test_workflow_has_choice_unit_tests_and_secrets(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:", "pull_request"):
            self.assertNotIn(trigger, workflow)
        for needle in ("aktion:", "type: choice", "- lesen", "- untertitel", "umask 077", "trap", "rm -f",
                       "timeout-minutes:", "contents: read"):
            self.assertIn(needle, workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        tests = workflow.index("python3 scripts/test_asc_app_info.py")
        call = workflow.index("python3 scripts/asc_app_info.py")
        self.assertLess(tests, call)
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))


if __name__ == "__main__":
    unittest.main()
