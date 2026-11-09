"""Tests für asc_version_texts.py und .github/workflows/asc-version-texts.yml (#842 Schnitt 3).

Aufruf: python3 scripts/test_asc_version_texts.py
Gegen einen lokalen Nachbau mit veränderlichem Zustand. Er bildet nur Apples echte Pfade und Formen ab (Version:
`platform`, `versionString`, `appStoreState`; Lokalisierung: `locale`, `description`, `keywords`, `supportUrl`,
`promotionalText`) und prüft die Form: welche Version gewählt wird, welche Aufrufe hinausgehen, nichts vor der Prüfung
des Textes, kein Schreiben ohne Abweichung, keine Zugangsdaten in der Ausgabe. Ob Apple den PATCH-Umschlag und die
Feldgrenzen annimmt, zeigt nur der echte Handlauf `aktion=texte` (Definition of Done der Spec).
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

SCRIPT = SCRIPTS / "asc_version_texts.py"
REPO = SCRIPTS.parent
WORKFLOW = REPO / ".github" / "workflows" / "asc-version-texts.yml"
TEXT_FILE = REPO / "docs" / "reference" / "app-store-texte.md"

DESCRIPTION = "Say it in one sentence – Loose Ends takes care of the rest.\n\nCAPTURE\n• Type or dictate\n• Share sheet"
KEYWORDS = "to-do,todo,reminders,dictation"
SUPPORT = "https://www.henemm.com/footer-information/contact/"
PROMO = "Say it in one sentence."
OLD = "Old words of the store page"
RAW_SECRET = "Roh-Antwort-Geheim-842"
FENCE = "```"


def text_file(description=DESCRIPTION, keywords=KEYWORDS, support=SUPPORT, promo=PROMO, locale="en-US",
              drop=(), close=True, whats_new=None):
    """Textdatei im Format der Spec; `drop` lässt Felder weg, `close=False` den schließenden Marker."""
    lines = ["# Store-Texte", "", "Vorspann. Schlüsselwörter: stehen hier nicht, Werbetext: auch nicht.", "",
             f"## {locale}", ""]
    if "Beschreibung" not in drop:
        lines += ["Beschreibung:", FENCE, description] + ([FENCE] if close else []) + [""]
    if "Schlüsselwörter" not in drop:
        lines += [f"Schlüsselwörter: {keywords}"]
    if "Support-URL" not in drop:
        lines += [f"Support-URL: {support}"]
    if promo is not None:
        lines += [f"Werbetext: {promo}"]
    if whats_new is not None:
        lines += [f"Neu in dieser Version: {whats_new}"]
    return "\n".join(lines) + "\n"


def de_section(promo="Deutscher Werbetext von 1.0.", whats_new="Jetzt auch auf Englisch.", extra=()):
    """Abschnitt `## de-DE` ohne Beschreibung; `extra` hängt weitere Zeilen an."""
    lines = ["", "## de-DE", ""]
    if promo is not None:
        lines.append(f"Werbetext: {promo}")
    if whats_new is not None:
        lines.append(f"Neu in dieser Version: {whats_new}")
    return "\n".join(lines + list(extra)) + "\n"


def version(version_id, platform, state, number="1.0"):
    return {"id": version_id, "type": "appStoreVersions",
            "attributes": {"platform": platform, "versionString": number, "appStoreState": state}}


def loc(loc_id, locale, description=OLD, keywords=OLD, support=OLD, promo=OLD):
    return {"id": loc_id, "type": "appStoreVersionLocalizations",
            "attributes": {"locale": locale, "description": description, "keywords": keywords,
                           "supportUrl": support, "promotionalText": promo}}


def wanted_loc(loc_id="L2", locale="en-US"):
    return loc(loc_id, locale, DESCRIPTION, KEYWORDS, SUPPORT, PROMO)


class FakeASC:
    """Nachbau mit Zustand: GET liest, PATCH/POST schreiben in den Zustand; jede Anfrage wird gemerkt."""

    def __init__(self, versions, localizations=None, write_status=None, ignore_writes=False, error_code=None):
        self.versions = [copy.deepcopy(item) for item in versions]
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
        if url == "/v1/apps/APP1/appStoreVersions":
            return 200, {"data": self.versions}
        for item in self.versions:
            if url == f"/v1/appStoreVersions/{item['id']}/appStoreVersionLocalizations":
                return 200, {"data": self.localizations.get(item["id"], [])}
        return 404, {}

    def write(self, method, path, body):
        if self.ignore_writes:
            return 200, {"data": {}}
        data = body["data"]
        if method == "PATCH" and path.startswith("/v1/appStoreVersionLocalizations/"):
            for items in self.localizations.values():
                for item in items:
                    if path == f"/v1/appStoreVersionLocalizations/{item['id']}":
                        item["attributes"].update(data.get("attributes", {}))
                        return 200, {"data": item}
        if method == "POST" and path == "/v1/appStoreVersionLocalizations":
            version_id = data["relationships"]["appStoreVersion"]["data"]["id"]
            created = {"id": f"NEW-{data['attributes']['locale']}", "type": "appStoreVersionLocalizations",
                       "attributes": dict(data["attributes"])}
            self.localizations.setdefault(version_id, []).append(created)
            return 201, {"data": created}
        return 404, {}

    def writes(self):
        return [(method, path, body) for method, path, body in self.requests if method != "GET"]

    def paths(self):
        return [path.split("?")[0] for _, path, _ in self.requests]

    def close(self):
        self.server.shutdown()


IOS_NEW = version("V2", "IOS", "PREPARE_FOR_SUBMISSION", "1.0.1")
IOS_LIVE = version("V1", "IOS", "READY_FOR_SALE")
MAC_LIVE = version("V3", "MAC_OS", "READY_FOR_SALE")
EMPTY_EN = loc("L2", "en-US", "", None, None, None)


class VersionTextsTests(unittest.TestCase):
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

    def run_texts(self, fake, aktion, text=None):
        path = Path(self.tmp.name) / "texte.md"
        path.write_text(text if text is not None else text_file(), encoding="utf-8")
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", VERSION_TEXTS_FILE=str(path))
        return subprocess.run([sys.executable, str(SCRIPT), aktion], env=env, capture_output=True, text=True,
                              timeout=120)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("::error::", result.stdout)

    def ios_state(self, record):
        return self.fake(versions=[IOS_LIVE, IOS_NEW, MAC_LIVE], localizations={"V2": [record]})

    # AC-1
    def test_invalid_text_file_aborts_before_any_request(self):
        cases = [
            (text_file(drop=("Beschreibung",)), ("en-US", "Beschreibung")),
            (text_file(drop=("Schlüsselwörter",)), ("en-US", "Schlüsselwörter")),
            (text_file(drop=("Support-URL",)), ("en-US", "Support-URL")),
            (text_file(description="x" * 4001), ("en-US", "Beschreibung", "4001", "4000")),
            (text_file(promo="p" * 171), ("en-US", "Werbetext", "171", "170")),
            (text_file(keywords="é" * 50 + "a"), ("en-US", "Schlüsselwörter", "101", "100")),
            (text_file(keywords="to-do, todo"), ("en-US", "Schlüsselwörter", "Leerzeichen")),
            (text_file(support="http://www.henemm.com/contact/"), ("en-US", "Support-URL", "https://")),
            (text_file(close=False), ("en-US", "Beschreibung")),
            ("# Store-Texte\n\nNur Vorspann, kein Abschnitt.\n", ("Abschnitt",)),
        ]
        for text, needles in cases:
            fake = self.ios_state(EMPTY_EN)
            result = self.run_texts(fake, "texte", text=text)
            self.assert_failed(result)
            for needle in needles:
                self.assertIn(needle, result.stdout, (needle, text[:200]))
            self.assertEqual(fake.requests, [], text[:200])

    # AC-2
    def test_text_file_parses_description_block_and_fields(self):
        from asc_version_texts import wanted_texts
        description = "\n  Zeile eins – mit Gedankenstrich\n\n• Punkt A\n• Punkt B\n\nSchluss.\n\n"
        wanted = wanted_texts(text_file(description=description))
        self.assertEqual(list(wanted), ["en-US"])
        values = wanted["en-US"]
        self.assertEqual(values["description"], description.strip("\n"))
        self.assertEqual(values["keywords"], KEYWORDS)
        self.assertEqual(values["supportUrl"], SUPPORT)
        self.assertEqual(values["promotionalText"], PROMO)

    # AC-2
    def test_repo_text_file_parses_and_fits_limits(self):
        from asc_version_texts import wanted_texts
        wanted = wanted_texts(TEXT_FILE.read_text(encoding="utf-8"))
        self.assertEqual(sorted(wanted), ["de-DE", "en-US"])
        german = wanted["de-DE"]
        self.assertTrue(german["promotionalText"].strip())
        self.assertLessEqual(len(german["promotionalText"]), 170)
        self.assertNotIn("description", german)
        for locale in wanted:
            self.assertTrue(wanted[locale]["whatsNew"].strip(), locale)
            self.assertLessEqual(len(wanted[locale]["whatsNew"]), 4000, locale)
        values = wanted["en-US"]
        self.assertTrue(values["description"].strip())
        self.assertLessEqual(len(values["description"]), 4000)
        self.assertTrue(values["keywords"])
        self.assertLessEqual(len(values["keywords"].encode("utf-8")), 100)
        self.assertNotIn(", ", values["keywords"])
        self.assertLessEqual(len(values.get("promotionalText") or ""), 170)
        self.assertTrue(values["supportUrl"].startswith("https://"))

    # AC-3
    def test_selects_only_editable_version_per_platform(self):
        fake = self.ios_state(EMPTY_EN)
        fake.localizations["V1"] = [loc("L1", "en-US")]
        fake.localizations["V3"] = [loc("L3", "en-US")]
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appStoreVersionLocalizations/L2")])
        for path in fake.paths():
            self.assertNotIn("/appStoreVersions/V1/", path)
            self.assertNotIn("/appStoreVersions/V3/", path)

    # AC-4
    def test_no_editable_version_prints_message_and_exits_zero(self):
        fake = self.fake(versions=[IOS_LIVE, MAC_LIVE, version("V4", "IOS", "IN_REVIEW", "1.0.2")])
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        for needle in ("keine bearbeitbare Version", "READY_FOR_SALE", "IN_REVIEW"):
            self.assertIn(needle, result.stdout)
        self.assertEqual(fake.writes(), [])
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=0"), result.stdout)
        fake = self.ios_state(EMPTY_EN)
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertIn("keine bearbeitbare Version MAC_OS", result.stdout)
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)

    # AC-5
    def test_several_editable_versions_of_one_platform_abort(self):
        fake = self.fake(versions=[IOS_NEW, version("V5", "IOS", "PREPARE_FOR_SUBMISSION", "1.0.2")],
                         localizations={"V2": [EMPTY_EN], "V5": [loc("L5", "en-US")]})
        result = self.run_texts(fake, "texte")
        self.assert_failed(result)
        self.assertIn("mehrdeutig", result.stdout)
        self.assertEqual(fake.writes(), [])

    # AC-6
    def test_different_text_patches_once_with_changed_fields_only(self):
        record = loc("L2", "en-US", DESCRIPTION, OLD, "", PROMO)
        fake = self.ios_state(record)
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appStoreVersionLocalizations/L2")])
        data = fake.writes()[0][2]["data"]
        self.assertEqual(data["type"], "appStoreVersionLocalizations")
        self.assertEqual(data["id"], "L2")
        self.assertEqual(data["attributes"], {"keywords": KEYWORDS, "supportUrl": SUPPORT})

    # AC-6, AC-11
    def test_empty_en_us_record_gets_all_fields_by_patch(self):
        fake = self.ios_state(EMPTY_EN)
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appStoreVersionLocalizations/L2")])
        self.assertEqual(fake.writes()[0][2]["data"]["attributes"],
                         {"description": DESCRIPTION, "keywords": KEYWORDS, "supportUrl": SUPPORT,
                          "promotionalText": PROMO})
        self.assertIn("gegenprobe gleich=ja", result.stdout)
        self.assertIn("zusammenfassung geschrieben=1", result.stdout)

    # AC-7
    def test_missing_record_posts_with_locale_fields_and_relationship(self):
        fake = self.fake(versions=[IOS_LIVE, IOS_NEW], localizations={"V2": [loc("L9", "de-DE")]})
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("POST", "/v1/appStoreVersionLocalizations")])
        data = fake.writes()[0][2]["data"]
        self.assertEqual(data["type"], "appStoreVersionLocalizations")
        self.assertEqual(data["attributes"], {"locale": "en-US", "description": DESCRIPTION, "keywords": KEYWORDS,
                                              "supportUrl": SUPPORT, "promotionalText": PROMO})
        self.assertEqual(data["relationships"]["appStoreVersion"]["data"], {"type": "appStoreVersions", "id": "V2"})
        self.assertIn("gegenprobe gleich=ja", result.stdout)

    # AC-8
    def test_equal_values_write_nothing(self):
        fake = self.ios_state(wanted_loc())
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual(fake.writes(), [])
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=0"), result.stdout)
        self.assertNotIn("gegenprobe", result.stdout)

    # AC-9
    def test_only_locales_from_file_are_touched(self):
        german = loc("LDE", "de-DE", "Deutsche Beschreibung", "deutsch,wörter", "https://example.de", "Deutsch")
        fake = self.fake(versions=[IOS_NEW], localizations={"V2": [german, EMPTY_EN]})
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("PATCH", "/v1/appStoreVersionLocalizations/L2")])
        self.assertEqual(fake.localizations["V2"][0], german)
        self.assertNotIn("LDE", " ".join(fake.paths()))

    # AC-10
    def test_promotional_text_is_optional(self):
        fake = self.ios_state(loc("L2", "en-US", OLD, OLD, OLD, "Alter Werbetext"))
        result = self.run_texts(fake, "texte", text=text_file(promo=None))
        self.assert_ok(result)
        self.assertEqual(len(fake.writes()), 1)
        self.assertNotIn("promotionalText", fake.writes()[0][2]["data"]["attributes"])
        self.assertEqual(fake.localizations["V2"][0]["attributes"]["promotionalText"], "Alter Werbetext")
        fake = self.ios_state(loc("L2", "en-US", OLD, OLD, OLD, "Alter Werbetext"))
        result = self.run_texts(fake, "texte")
        self.assert_ok(result)
        self.assertEqual(fake.writes()[0][2]["data"]["attributes"]["promotionalText"], PROMO)

    # AC-11
    def test_verification_mismatch_is_error(self):
        fake = self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]}, ignore_writes=True)
        result = self.run_texts(fake, "texte")
        self.assert_failed(result)
        self.assertIn("Gegenprobe", result.stdout)
        self.assertEqual(len(fake.writes()), 1, fake.writes())

    # AC-12
    def test_403_and_409_give_clear_message(self):
        for status, word, code in ((403, "gesperrt", None), (409, "Konflikt", "ENTITY_ERROR.ATTRIBUTE.INVALID")):
            fake = self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]}, write_status=status,
                             error_code=code)
            result = self.run_texts(fake, "texte")
            self.assert_failed(result)
            self.assertIn(word, result.stdout)
            if code:
                self.assertIn(code, result.stdout)
            self.assertNotIn(RAW_SECRET, result.stdout + result.stderr)
            self.assertNotIn("zusammenfassung geschrieben", result.stdout)

    # AC-13
    def test_lesen_never_writes_and_prints_values(self):
        record = loc("L2", "en-US", OLD, OLD, OLD, OLD)
        fake = self.ios_state(record)
        result = self.run_texts(fake, "lesen", text="kaputt, wird für lesen nicht gebraucht")
        self.assert_ok(result)
        self.assertEqual([m for m, _, _ in fake.requests if m != "GET"], [])
        for needle in ("READY_FOR_SALE", "PREPARE_FOR_SUBMISSION", "IOS", "MAC_OS", "en-US", OLD, str(len(OLD))):
            self.assertIn(needle, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung geschrieben=0"), result.stdout)

    # AC-14
    def test_writes_only_localization_paths_and_submits_nothing(self):
        runs = [self.ios_state(EMPTY_EN),
                self.fake(versions=[IOS_NEW], localizations={"V2": [loc("L9", "de-DE")]})]
        for fake in runs:
            self.assert_ok(self.run_texts(fake, "texte"))
            self.assertTrue(fake.writes())
            for method, path, _ in fake.writes():
                self.assertTrue(path == "/v1/appStoreVersionLocalizations"
                                or path.startswith("/v1/appStoreVersionLocalizations/"), (method, path))
                for word in ("Submission", "appStoreVersions", "Screenshot", "Preview"):
                    self.assertNotIn(word, path)

    # AC-14
    def test_unknown_action_aborts_before_any_request(self):
        fake = self.ios_state(EMPTY_EN)
        result = self.run_texts(fake, "einreichen")
        self.assert_failed(result)
        self.assertEqual(fake.requests, [])

    # AC-14
    def test_output_has_no_secrets(self):
        key_body = "".join(self.key.read_text().splitlines()[1:-1])
        secrets = (key_body, "BEGIN", "PRIVATE KEY", "Bearer", "eyJ", RAW_SECRET)
        runs = [(self.ios_state(EMPTY_EN), "texte"),
                (self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]}, write_status=403), "texte"),
                (self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]}, write_status=409), "texte"),
                (self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]}, ignore_writes=True), "texte"),
                (self.ios_state(EMPTY_EN), "lesen")]
        for fake, aktion in runs:
            result = self.run_texts(fake, aktion)
            output = result.stdout + result.stderr
            self.assertTrue("::error::" in result.stdout or "zusammenfassung geschrieben=" in result.stdout, output)
            for secret in secrets:
                self.assertNotIn(secret, output, (aktion, secret))

    # 5a-2 AC-1
    def test_whats_new_line_is_parsed_and_limited(self):
        from asc_version_texts import wanted_texts
        wanted = wanted_texts(text_file(whats_new="Neu: Englisch."))
        self.assertEqual(wanted["en-US"]["whatsNew"], "Neu: Englisch.")
        self.assertEqual(len(wanted_texts(text_file(whats_new="w" * 4000))["en-US"]["whatsNew"]), 4000)
        fake = self.ios_state(EMPTY_EN)
        result = self.run_texts(fake, "texte", text=text_file(whats_new="w" * 4001))
        self.assert_failed(result)
        for needle in ("en-US", "Neu in dieser Version", "4001", "4000"):
            self.assertIn(needle, result.stdout)
        self.assertEqual(fake.requests, [])

    # 5a-2 AC-2
    def test_section_without_description_may_carry_only_promo_and_whats_new(self):
        from asc_version_texts import wanted_texts
        self.assertIn("de-DE", wanted_texts(text_file() + de_section()))
        self.assertIn("de-DE", wanted_texts(text_file() + de_section(promo=None)))
        self.assertIn("de-DE", wanted_texts(text_file() + de_section(whats_new=None)))
        cases = [(de_section(extra=["Schlüsselwörter: a,b"]), "Schlüsselwörter"),
                 (de_section(extra=[f"Support-URL: {SUPPORT}"]), "Support-URL"),
                 (de_section(promo=None, whats_new=None), "de-DE")]
        for section, needle in cases:
            fake = self.ios_state(EMPTY_EN)
            result = self.run_texts(fake, "texte", text=text_file() + section)
            self.assert_failed(result)
            self.assertIn("de-DE", result.stdout)
            self.assertIn(needle, result.stdout)
            self.assertEqual(fake.requests, [], section)

    # 5a-2 AC-3
    def test_section_with_description_still_requires_all_three(self):
        for dropped in ("Schlüsselwörter", "Support-URL"):
            fake = self.ios_state(EMPTY_EN)
            result = self.run_texts(fake, "texte", text=text_file(drop=(dropped,), whats_new="Neu"))
            self.assert_failed(result)
            self.assertIn(dropped, result.stdout)
            self.assertEqual(fake.requests, [])

    # 5a-2 AC-4
    def test_section_without_description_for_missing_locale_is_fatal_and_writes_nothing(self):
        fake = self.fake(versions=[IOS_NEW], localizations={"V2": [EMPTY_EN]})
        result = self.run_texts(fake, "texte", text=text_file() + de_section())
        self.assert_failed(result)
        self.assertIn("de-DE", result.stdout)
        self.assertIn("fehlt bei Apple", result.stdout)
        self.assertEqual(fake.writes(), [])

    # 5a-2 AC-5
    def test_de_section_patches_only_promo_and_whats_new(self):
        german = {"IOS": loc("LDE1", "de-DE", "Deutsche Beschreibung", "de,wörter", "https://example.de", "alt"),
                  "MAC": loc("LDE3", "de-DE", "Deutsche Beschreibung", "de,wörter", "https://example.de", "alt")}
        fake = self.fake(versions=[IOS_NEW, version("V4", "MAC_OS", "PREPARE_FOR_SUBMISSION", "1.0.1")],
                         localizations={"V2": [wanted_loc(), german["IOS"]], "V4": [wanted_loc("L4"), german["MAC"]]})
        result = self.run_texts(fake, "texte", text=text_file() + de_section())
        self.assert_ok(result)
        self.assertEqual(len(fake.writes()), 2, fake.writes())
        for method, path, body in fake.writes():
            self.assertEqual(method, "PATCH")
            self.assertIn(path.rsplit("/", 1)[1], ("LDE1", "LDE3"))
            self.assertEqual(body["data"]["attributes"],
                             {"promotionalText": "Deutscher Werbetext von 1.0.", "whatsNew": "Jetzt auch auf Englisch."})
        self.assertEqual(result.stdout.count("gegenprobe gleich=ja"), 2)

    # 5a-2 AC-6
    def test_missing_mac_en_us_is_posted_with_all_fields_including_whats_new(self):
        mac = version("V4", "MAC_OS", "PREPARE_FOR_SUBMISSION", "1.0.1")
        fake = self.fake(versions=[mac], localizations={"V4": [loc("L9", "de-DE")]})
        result = self.run_texts(fake, "texte", text=text_file(whats_new="Now English."))
        self.assert_ok(result)
        self.assertEqual([(m, p) for m, p, _ in fake.writes()], [("POST", "/v1/appStoreVersionLocalizations")])
        data = fake.writes()[0][2]["data"]
        self.assertEqual(data["attributes"], {"locale": "en-US", "description": DESCRIPTION, "keywords": KEYWORDS,
                                              "supportUrl": SUPPORT, "promotionalText": PROMO,
                                              "whatsNew": "Now English."})
        self.assertEqual(data["relationships"]["appStoreVersion"]["data"], {"type": "appStoreVersions", "id": "V4"})

    # 5a-2 AC-7
    def test_second_run_writes_nothing(self):
        german = loc("LDE1", "de-DE", "Deutsche Beschreibung", "de,wörter", "https://example.de", "alt")
        english = wanted_loc()
        english["attributes"]["whatsNew"] = "Now English."
        fake = self.fake(versions=[IOS_NEW], localizations={"V2": [english, german]})
        text = text_file(whats_new="Now English.") + de_section()
        self.assert_ok(self.run_texts(fake, "texte", text=text))
        first = len(fake.writes())
        self.assertEqual(first, 1)
        result = self.run_texts(fake, "texte", text=text)
        self.assert_ok(result)
        self.assertEqual(len(fake.writes()), first)
        self.assertEqual(result.stdout.count("unverändert"), 2)

    # 5a-2 AC-8
    def test_lesen_shows_published_promotional_text_and_never_writes(self):
        live_ios = loc("L1", "de-DE", OLD, OLD, OLD, "Veröffentlichter Werbetext")
        live_mac = loc("L3", "de-DE", OLD, OLD, OLD, "Mac Werbetext")
        fake = self.fake(versions=[IOS_LIVE, IOS_NEW, MAC_LIVE],
                         localizations={"V1": [live_ios], "V2": [EMPTY_EN], "V3": [live_mac]})
        result = self.run_texts(fake, "lesen")
        self.assert_ok(result)
        self.assertEqual([m for m, _, _ in fake.requests if m != "GET"], [])
        lines = result.stdout.splitlines()
        self.assertIn(f"veröffentlicht IOS 1.0 de-DE Werbetext zeichen={len('Veröffentlichter Werbetext')}: "
                      "Veröffentlichter Werbetext", lines)
        self.assertIn(f"veröffentlicht MAC_OS 1.0 de-DE Werbetext zeichen={len('Mac Werbetext')}: Mac Werbetext",
                      lines)


class WorkflowTests(unittest.TestCase):
    # AC-15
    def test_workflow_has_choice_unit_tests_and_secrets(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:", "pull_request"):
            self.assertNotIn(trigger, workflow)
        for needle in ("aktion:", "type: choice", "- lesen", "- texte", "umask 077", "trap", "rm -f",
                       "timeout-minutes:", "contents: read"):
            self.assertIn(needle, workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        tests = workflow.index("python3 scripts/test_asc_version_texts.py")
        call = workflow.index("python3 scripts/asc_version_texts.py")
        self.assertLess(tests, call)
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))


if __name__ == "__main__":
    unittest.main()
