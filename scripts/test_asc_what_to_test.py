"""Tests für asc_what_to_test.py und seine Schritte in testflight.yml (#347).

Aufruf: python3 scripts/test_asc_what_to_test.py
Gegen einen lokalen Nachbau der App-Store-Connect-API; Apples echte Antworten zeigt nur der echte Lauf.
"""
import json
import os
import plistlib
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

from asc_wait_build import Fatal  # noqa: E402
from asc_what_to_test import split_sections  # noqa: E402

SCRIPT = SCRIPTS / "asc_what_to_test.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "testflight.yml"
BUILD = "42"
TEXT = "Siri auf Deutsch: „Neue Aufgabe in Loose Ends“ sagen."


class FakeASC:
    """Antwortet auf Apps, Builds und Sprachfassungen; merkt sich jede PATCH- und POST-Anfrage."""

    def __init__(self, localizations, patch_status=200, error_body=None):
        self.localizations, self.patch_status, self.writes = localizations, patch_status, []
        self.error_body = error_body  # Rumpf der Fehlerantwort: dict wird JSON, bytes bleiben roh
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body=None):
                raw = body if isinstance(body, bytes) else json.dumps(body or {}).encode()
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
                failed = self.command == "PATCH" and fake.patch_status >= 400
                self.reply(fake.patch_status if self.command == "PATCH" else 201,
                           fake.error_body if failed else None)

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

    def test_creates_the_localization_of_every_shipped_language_when_missing(self):
        fake = FakeASC([])
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({(m, p) for m, p, _ in fake.writes}, {("POST", "/v1/betaBuildLocalizations")})
        created = {body["data"]["attributes"]["locale"]: body["data"]["attributes"]["whatsNew"] for _, _, body in fake.writes}
        self.assertEqual(created, {"de-DE": TEXT, "en-US": TEXT})
        for _, _, body in fake.writes:
            self.assertEqual(body["data"]["relationships"]["build"]["data"], {"type": "builds", "id": "B42"})
        self.assertIn("whatToTest gesetzt für", result.stdout)

    def test_each_localization_gets_its_own_section(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "en-US"}},
                        {"id": "L2", "attributes": {"locale": "de-DE"}},
                        {"id": "L3", "attributes": {"locale": "fr-FR"}}])
        self.addCleanup(fake.close)
        result = self.run_script(fake, text="de: Deutscher Text\nen: English text")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        sent = {p.rsplit("/", 1)[1]: body["data"]["attributes"]["whatsNew"] for _, p, body in fake.writes}
        self.assertEqual(sent, {"L1": "English text", "L2": "Deutscher Text", "L3": "Deutscher Text"})

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

    # AC-1
    def test_rejected_write_names_apple_error_code(self):
        body = {"errors": [{"code": "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE", "detail": "geheim"}]}
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}], patch_status=409, error_body=body)
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 1)
        self.assertIn("HTTP 409", result.stdout)
        self.assertIn("ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE", result.stdout)
        self.assertNotIn("geheim", result.stdout + result.stderr)

    # AC-2
    def test_error_code_filter_and_limit(self):
        codes = ["kleinwert mit leerzeichen"] + [f"CODE_{n}" for n in range(7)]
        body = {"errors": [{"code": code} for code in codes]}
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}], patch_status=409, error_body=body)
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertNotIn("kleinwert", result.stdout)
        for n in range(5):
            self.assertIn(f"CODE_{n}", result.stdout)
        self.assertNotIn("CODE_5", result.stdout)

    # AC-3
    def test_unreadable_error_body_keeps_old_message(self):
        for body in (b"kein json", {"errors": 7}):
            fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}], patch_status=409, error_body=body)
            self.addCleanup(fake.close)
            result = self.run_script(fake)
            self.assertEqual(result.returncode, 1)
            self.assertIn("ASC answered HTTP 409 for PATCH", result.stdout)
            self.assertNotIn("codes", result.stdout)

    # AC-3
    def test_numeric_error_code_keeps_old_message(self):
        body = {"errors": [{"code": 409}]}
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}], patch_status=409, error_body=body)
        self.addCleanup(fake.close)
        result = self.run_script(fake)
        self.assertEqual(result.returncode, 1)
        self.assertIn("ASC answered HTTP 409 for PATCH", result.stdout)
        self.assertNotIn("codes", result.stdout)
        self.assertNotIn("TypeError", result.stderr)


class SectionTests(unittest.TestCase):
    def test_sections_split_by_language_marker(self):
        self.assertEqual(split_sections("de: A\nen: B"), {"de-DE": "A", "en-US": "B"})
        self.assertEqual(split_sections("de: A\nweiter\nen: B"), {"de-DE": "A\nweiter", "en-US": "B"})

    def test_text_without_marker_is_german(self):
        self.assertEqual(split_sections("A"), {"de-DE": "A"})
        self.assertEqual(split_sections("Hinweis: A"), {"de-DE": "Hinweis: A"})

    def test_missing_section_falls_back_to_german(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        tester = WhatToTestTests()
        tester.setUp()
        self.addCleanup(tester.tearDown)
        result = tester.run_script(fake, text="de: A")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        sent = {(m, body["data"]["attributes"].get("locale", p.rsplit("/", 1)[1])): body["data"]["attributes"]["whatsNew"]
                for m, p, body in fake.writes}
        self.assertEqual(sent, {("PATCH", "L1"): "A", ("POST", "en-US"): "A"})

    def test_unknown_language_code_fails(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            shutil.copytree(SCRIPTS.parent / "Shared/Language", Path(folder) / "Shared/Language")
            pack = Path(folder) / "Shared/Language/LanguagePack.swift"
            pack.write_text(pack.read_text(encoding="utf-8").replace("[.english, .german]", "[.english, .german, .test]"),
                            encoding="utf-8")
            (pack.parent / "TestPack.swift").write_text('extension LanguagePack {\n    static let test = LanguagePack(\n        code: "zz",\n')
            with self.assertRaises(Fatal) as raised:
                split_sections("de: A", folder)
            self.assertIn("zz", str(raised.exception))


class WorkflowTests(unittest.TestCase):
    def test_workflow_asks_for_the_text_and_writes_it_after_processing(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("what_to_test:", workflow)
        self.assertIn("WHAT_TO_TEST: ${{ inputs.what_to_test || github.event.head_commit.message }}", workflow)
        self.assertLess(workflow.index("scripts/asc_wait_build.py"), workflow.index("scripts/asc_what_to_test.py"))


# Schnitt 4c-2a (#615): Konto-Bau — Berechtigung, Schalter, Kennzeichnung, Archivprüfungen
import asc_what_to_test  # noqa: E402

ROOT = SCRIPTS.parent
PROJECT = ROOT / "project.yml"
APP_ENTITLEMENTS = ROOT / "LooseEnds" / "LooseEnds.entitlements"
APP_INFO = ROOT / "LooseEnds" / "Info.plist"
APPLESIGNIN = "com.apple.developer.applesignin"
SWITCH_LINE = "plutil -replace LEAccountEnabled -bool YES LooseEnds/Info.plist"
CHECK_BEGIN, CHECK_END = "# account-switch-check:begin", "# account-switch-check:end"


def mark():
    value = getattr(asc_what_to_test, "ACCOUNT_BUILD_MARK", None)
    if not isinstance(value, str) or not value.strip():
        raise AssertionError("asc_what_to_test.ACCOUNT_BUILD_MARK fehlt")
    return value


def job(workflow, name):
    """Text eines Jobs (`  name:` bis zum nächsten Job auf derselben Einrückung)."""
    start = workflow.index(f"\n  {name}:\n") + 1
    following = re.search(r"\n  [a-z][a-z-]*:\n", workflow[start + len(name) + 3:])
    return workflow[start:] if following is None else workflow[start:start + len(name) + 3 + following.start()]


def step(job_text, name):
    """Text eines Schritts (`- name: <name>` bis zum nächsten `- name:`)."""
    start = job_text.index(f"- name: {name}\n")
    following = job_text.find("\n      - name:", start + 1)
    return job_text[start:] if following < 0 else job_text[start:following]


def app_target(key, path):
    import yaml
    project = yaml.safe_load(PROJECT.read_text(encoding="utf-8"))
    found = [target for target in project["targets"].values() if (target.get(key) or {}).get("path") == path]
    assert len(found) == 1, f"kein eindeutiges Ziel mit {key}.path {path}"
    return found[0][key].get("properties", {})


class AccountBuildSourceTests(unittest.TestCase):
    # AC-1
    def test_app_target_has_applesignin(self):
        self.assertEqual(app_target("entitlements", "LooseEnds/LooseEnds.entitlements").get(APPLESIGNIN), ["Default"])
        self.assertEqual(plistlib.loads(APP_ENTITLEMENTS.read_bytes()).get(APPLESIGNIN), ["Default"])

    # AC-2
    def test_account_switch_is_a_false_bool(self):
        properties = app_target("info", "LooseEnds/Info.plist")
        self.assertIs(properties.get("LEAccountEnabled"), False)
        self.assertNotIn("LEServiceURL", properties)
        info = plistlib.loads(APP_INFO.read_bytes())
        self.assertIn("LEAccountEnabled", info)
        self.assertIs(info["LEAccountEnabled"], False)
        self.assertNotIn("LEServiceURL", info)


class AccountBuildWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.workflow = WORKFLOW.read_text(encoding="utf-8")

    def assertIn(self, member, container, msg=None):  # Schrittblöcke sind lang: nur Fundstück und Ort melden
        if member not in container:
            self.fail(f"{member!r} fehlt{f' ({msg})' if msg else ''}")

    # AC-3
    def test_workflow_has_konto_input_default_false(self):
        inputs = self.workflow[self.workflow.index("    inputs:\n"):self.workflow.index("  push:\n")]
        found = re.search(r"\n      konto:\n((?:        .*\n)+)", inputs)
        self.assertIsNotNone(found, "Eingabe konto fehlt")
        self.assertIn("type: boolean", found.group(1))
        self.assertIn("default: false", found.group(1))
        top_env = self.workflow[self.workflow.index("\nenv:\n"):self.workflow.index("\njobs:\n")]
        self.assertIn("ACCOUNT_BUILD: ${{ inputs.konto == true && 'true' || 'false' }}", top_env)
        self.assertEqual(self.workflow.count("inputs.konto"), 1)

    # AC-4
    def test_switch_step_is_conditional_and_between_generate_and_archive(self):
        self.assertEqual(self.workflow.count(SWITCH_LINE), 2)
        for name, archive in (("upload", "Archive"), ("upload-mac", "Archive (macOS)")):
            text = job(self.workflow, name)
            switch = step(text, "Set the account switch")
            self.assertIn("if: env.ACCOUNT_BUILD == 'true'", switch, name)
            self.assertIn(SWITCH_LINE, switch, name)
            self.assertLess(text.index("- name: Generate project\n"), text.index("- name: Set the account switch\n"), name)
            self.assertLess(text.index("- name: Set the account switch\n"), text.index(f"- name: {archive}\n"), name)

    # AC-5
    def test_archive_checks_prove_switch_type_and_value(self):
        for name, check in (("upload", "Verify the archive is built against the iOS 27 SDK"),
                            ("upload-mac", "Verify the macOS archive")):
            text = step(job(self.workflow, name), check)
            for needle in ("LEAccountEnabled", "plutil -type", CHECK_BEGIN, CHECK_END):
                self.assertIn(needle, text, name)
            self.assertIn("account_switch ", text[text.index(CHECK_END):], name)

    # AC-5: der Prüfausschnitt selbst, gegen Beispiel-Plists ausgeführt (4 Fälle × 2 Eingaben)
    def test_switch_check_logic(self):
        snippets = re.findall(re.escape(CHECK_BEGIN) + r"\n(.*?)\n\s*" + re.escape(CHECK_END), self.workflow, re.S)
        self.assertEqual(len(snippets), 2, "Prüfausschnitt fehlt in der iOS- oder Mac-Prüfung")
        cases = {"bool true": "<true/>", "bool false": "<false/>", "string YES": "<string>YES</string>", "fehlt": ""}
        expected = {("bool true", "true"): 0, ("bool true", "false"): 1, ("bool false", "true"): 1,
                    ("bool false", "false"): 0, ("string YES", "true"): 1, ("string YES", "false"): 1,
                    ("fehlt", "true"): 1, ("fehlt", "false"): 1}
        with tempfile.TemporaryDirectory() as folder:
            for index, snippet in enumerate(snippets):
                results = {}
                for case, value in cases.items():
                    plist = Path(folder) / f"{index}-{case.replace(' ', '-')}.plist"
                    entry = f"<key>LEAccountEnabled</key>{value}" if value else ""
                    plist.write_text('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
                                     f"<key>CFBundleIdentifier</key><string>x</string>{entry}</dict></plist>\n")
                    for wanted in ("true", "false"):
                        script = f'row() {{ :; }}\nfail=0\n{snippet}\naccount_switch "$1"\n[ "$fail" = 0 ]\n'
                        run = subprocess.run(["bash", "-c", script, "check", str(plist)], capture_output=True,
                                             text=True, env=dict(os.environ, ACCOUNT_BUILD=wanted))
                        results[(case, wanted)] = 0 if run.returncode == 0 else 1
                self.assertEqual(results, expected, f"Prüfausschnitt {index}")

    # AC-6
    def test_archive_checks_prove_applesignin_entitlement(self):
        ios = step(job(self.workflow, "upload"), "Verify the archive is built against the iOS 27 SDK")
        self.assertIn(f"entitled com.henning.looseends {APPLESIGNIN}", ios)
        mac = step(job(self.workflow, "upload-mac"), "Verify the macOS archive")
        keys = re.search(r"for key in ([^;]+); do", mac[mac.index("ents=$(codesign"):])
        self.assertIsNotNone(keys)
        self.assertIn(APPLESIGNIN, keys.group(1).split())


class AccountBuildMarkTests(unittest.TestCase):
    def setUp(self):
        self.tester = WhatToTestTests()
        self.tester.setUp()
        self.addCleanup(self.tester.tearDown)

    def run_with(self, fake, text, account):
        saved = os.environ.pop("ACCOUNT_BUILD", None)
        if account is not None:
            os.environ["ACCOUNT_BUILD"] = account
        try:
            return self.tester.run_script(fake, text=text)
        finally:
            os.environ.pop("ACCOUNT_BUILD", None)
            if saved is not None:
                os.environ["ACCOUNT_BUILD"] = saved

    # AC-7
    def test_mark_is_added_to_every_section(self):
        marked = asc_what_to_test.mark_account_build({"de-DE": "Deutsch", "en-US": "English"})
        self.assertEqual(marked, {"de-DE": f"Deutsch\n{mark()}", "en-US": f"English\n{mark()}"})
        self.assertEqual(asc_what_to_test.mark_account_build(marked), marked)
        self.assertTrue(asc_what_to_test.is_account_build(["frei", f"x\n{mark()}"]))
        self.assertFalse(asc_what_to_test.is_account_build(["frei", "auch frei"]))
        self.assertFalse(asc_what_to_test.is_account_build([]))

    # AC-7
    def test_mark_not_added_when_off(self):
        mark()
        for account in (None, "false", "TRUE", "1", "yes"):
            fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}])
            self.addCleanup(fake.close)
            result = self.run_with(fake, TEXT, account)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual([body["data"]["attributes"]["whatsNew"] for _, _, body in fake.writes], [TEXT, TEXT],
                             account)

    # AC-7
    def test_mark_respects_length_limit(self):
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        result = self.run_with(fake, "x" * 3990, "true")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("at most 4000", result.stdout)
        self.assertEqual(fake.writes, [])
        fake = FakeASC([{"id": "L1", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        self.assertEqual(self.run_with(fake, "x" * 3990, "false").returncode, 0)

    # AC-7
    def test_mark_in_every_written_localization(self):
        fake = FakeASC([{"id": "L2", "attributes": {"locale": "de-DE"}}])
        self.addCleanup(fake.close)
        result = self.run_with(fake, "de: Deutsch\nen: English", "true")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        sent = {method: body["data"]["attributes"]["whatsNew"] for method, _, body in fake.writes}
        self.assertEqual(sent, {"PATCH": f"Deutsch\n{mark()}", "POST": f"English\n{mark()}"})

    # AC-8
    def test_mark_defined_once(self):
        wording = mark()
        store = (SCRIPTS / "asc_store_version.py").read_text(encoding="utf-8")
        self.assertEqual(SCRIPT.read_text(encoding="utf-8").count(wording), 1)
        self.assertEqual(store.count(wording), 0)
        self.assertRegex(store, r"from asc_what_to_test import [^\n]*(ACCOUNT_BUILD_MARK|is_account_build)")
        self.assertEqual(WORKFLOW.read_text(encoding="utf-8").count(wording), 0)

    # AC-12
    def test_docs_name_account_build(self):
        wording = mark()
        guide = (ROOT / "docs" / "reference" / "testflight.md").read_text(encoding="utf-8")
        for needle in ("konto", APPLESIGNIN, "LEAccountEnabled"):
            self.assertIn(needle, guide)
        claude = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        ship = claude[claude.index("\n## Ship\n") + 1:]
        ship = ship[: ship.index("\n## ")]
        self.assertIn("konto", ship)
        self.assertNotIn(wording, guide)
        self.assertNotIn(wording, claude)


if __name__ == "__main__":
    unittest.main()
