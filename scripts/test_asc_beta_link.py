"""Tests für asc_beta_link.py und den Job `link` in .github/workflows/asc-beta.yml (#705 Schnitt 2b-2c).

Aufruf: python3 scripts/test_asc_beta_link.py
Gegen einen lokalen Nachbau von Apples Gruppen-Schnittstelle: er prüft nur die Form (welche Aufrufe, nie ein Link ohne
bestätigtes Limit, nichts in der Ausgabe außer Zustandswörtern). Ob Apple das Limit zusammen mit dem Link annimmt, zeigt
nur der echte Lauf `aktion=link`.
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

from test_asc_beta_invite import BUILDS, LINK, WANTED_QUERY, WORKFLOW, WORKFLOWS

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_beta_link.py"
INVITE = SCRIPTS / "asc_beta_invite.py"
DOC = SCRIPTS.parent / "docs" / "reference" / "testflight.md"
GROUP_ID = "G-7c41-1"
APPROVED = "BETA_APPROVED"
class _Missing:
    def __repr__(self):
        return "fehlt"


MISSING = _Missing()  # Nachbau ohne Feld publicLinkEnabled


class FakeLinkASC:
    """Eine externe Gruppe `Tester` mit Link-Attributen; PATCH ändert sie. Jede Anfrage wird gemerkt."""

    def __init__(self, extern=None, assigned=None, ignore_limit=False, break_reads_after_patch=False, fail_patch=None,
                 group_present=True, broken_detail=False, error_after_enable=False, fail_off_patch=None,
                 enabled=False, malformed_readback=None):
        attributes = {"name": "Tester", "isInternalGroup": False, "publicLinkEnabled": enabled,
                      "publicLinkLimitEnabled": False, "publicLinkLimit": None}
        if enabled is MISSING:
            del attributes["publicLinkEnabled"]
        self.group = {"id": GROUP_ID, "attributes": attributes}
        self.group_present = group_present
        self.extern = {b["id"]: APPROVED for b in BUILDS.values()} | dict(extern or {})
        self.assigned = {b["id"] for b in BUILDS.values()} if assigned is None else set(assigned)
        self.ignore_limit, self.break_reads, self.fail_patch, self.broken_detail = (
            ignore_limit, break_reads_after_patch, fail_patch, broken_detail)
        self.error_after_enable = error_after_enable  # Einschalt-PATCH wird angewendet, Antwort aber 500
        self.fail_off_patch = fail_off_patch  # nur der Ausschalt-PATCH scheitert mit diesem Status
        self.malformed_readback = malformed_readback  # Gruppenantwort nach dem ersten PATCH, sonst None
        self.patched = False
        self.requests = []
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

            def handle_any(self):
                length = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(length)) if length else None
                fake.requests.append((self.command, self.path, body))
                self.reply(*(fake.read(self.path) if self.command == "GET" else fake.write(self.command, self.path, body)))

            do_GET = do_POST = do_PATCH = do_DELETE = handle_any

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def read(self, path):
        route, _, query = path.partition("?")
        if route == "/v1/apps":
            return 200, {"data": [{"id": "APP1"}]}
        if route == "/v1/apps/APP1/betaGroups":
            if self.break_reads and self.patched:
                return 500, {}
            if self.malformed_readback is not None and self.patched:
                return 200, self.malformed_readback
            attributes = dict(self.group["attributes"])
            if attributes.get("publicLinkEnabled") is True:
                attributes["publicLink"] = LINK
            return 200, {"data": [{"id": GROUP_ID, "attributes": attributes}] if self.group_present else []}
        if route == f"/v1/betaGroups/{GROUP_ID}/relationships/builds":
            return 200, {"data": [{"type": "builds", "id": i} for i in sorted(self.assigned)]}
        if route == "/v1/builds":
            params = urllib.parse.parse_qs(query)
            platform = params.pop("filter[preReleaseVersion.platform]", [""])[0]
            hit = BUILDS.get(platform) if params == WANTED_QUERY else None
            return 200, {"data": [{"id": hit["id"], "attributes": {"version": hit["version"]}}] if hit else []}
        for build in BUILDS.values():
            if route == f"/v1/builds/{build['id']}/buildBetaDetail":
                if self.broken_detail:
                    return 404, {}
                return 200, {"data": {"id": "BD", "attributes": {"externalBuildState": self.extern[build["id"]]}}}
        return 404, {}

    def write(self, method, path, body):
        if method != "PATCH" or path != f"/v1/betaGroups/{GROUP_ID}":
            return 404, {}
        if self.fail_patch:
            status, code = self.fail_patch
            return status, {"errors": [{"status": str(status), "code": code}]}
        attributes = dict(body["data"]["attributes"])
        if self.fail_off_patch and attributes.get("publicLinkEnabled") is False:
            return self.fail_off_patch, {"errors": [{"status": str(self.fail_off_patch), "code": "FORBIDDEN_ERROR"}]}
        if self.ignore_limit:
            attributes.pop("publicLinkLimit", None)
        self.group["attributes"].update(attributes)
        self.patched = True
        if self.error_after_enable and attributes.get("publicLinkEnabled") is True:
            return 500, {}
        return 200, {"data": self.group}

    def patches(self):
        return [body["data"]["attributes"] for method, _, body in self.requests if method == "PATCH"]

    def close(self):
        self.server.shutdown()


MALFORMED_READBACKS = {
    "element-kein-objekt": {"data": ["x"]},
    "gruppe-ohne-id": {"data": [{"attributes": {"name": "Tester", "isInternalGroup": False}}]},
    "attribute-als-liste": {"data": [{"id": GROUP_ID, "attributes": ["a"]}]},
    "element-null": {"data": [None]},
}


class LinkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def fake(self, **kwargs):
        fake = FakeLinkASC(**kwargs)
        self.addCleanup(fake.close)
        return fake

    def link(self, fake, *args):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", ASC_PLATFORM="")
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True, timeout=120)

    def test_not_ready_build_is_not_enabled(self):
        for state in ("READY_FOR_BETA_SUBMISSION", "PROCESSING"):
            with self.subTest(state=state):
                fake = self.fake(extern={BUILDS["IOS"]["id"]: state})
                run = self.link(fake)
                self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assertEqual(fake.patches(), [])
                self.assertIn("link zustand=nicht-bereit plattform=IOS", run.stdout)
                self.assertIn(f"extern={state}", run.stdout)
        with self.subTest(state="unlesbar"):
            fake = self.fake(broken_detail=True)
            run = self.link(fake)
            self.assertEqual((run.returncode, fake.patches()), (0, []))
            self.assertIn("link zustand=nicht-bereit", run.stdout)

    def test_build_missing_in_group_is_not_ready(self):
        fake = self.fake(assigned={BUILDS["MAC_OS"]["id"]})
        run = self.link(fake)
        self.assertEqual((run.returncode, fake.patches()), (0, []))
        self.assertIn("link zustand=nicht-bereit plattform=IOS", run.stdout)

    def test_enable_sends_one_patch_with_limit_50(self):
        fake = self.fake()
        run = self.link(fake)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual(fake.patches(), [{"publicLinkEnabled": True, "publicLinkLimitEnabled": True, "publicLinkLimit": 50}])
        self.assertIn("link zustand=eingeschaltet limit=50", run.stdout)
        self.assertIn("zusammenfassung geschrieben=1", run.stdout)
        self.assertEqual(fake.requests[-1][0], "GET")  # nach dem PATCH wird gegengelesen

    def test_second_run_writes_nothing(self):
        fake = self.fake()
        self.link(fake)
        before = len(fake.patches())
        run = self.link(fake)
        self.assertEqual((run.returncode, len(fake.patches())), (0, before))
        self.assertIn("link zustand=vorhanden limit=50", run.stdout)
        self.assertIn("zusammenfassung geschrieben=0", run.stdout)

    def test_limit_mismatch_switches_back_off(self):
        fake = self.fake(ignore_limit=True)
        run = self.link(fake)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(len(fake.patches()), 2)
        self.assertEqual(fake.patches()[1], {"publicLinkEnabled": False})
        self.assertFalse(fake.group["attributes"]["publicLinkEnabled"])
        self.assertIn("link zustand=abgebrochen grund=limit", run.stdout)

    def test_unreadable_readback_switches_back_off(self):
        fake = self.fake(break_reads_after_patch=True)
        run = self.link(fake)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(fake.patches()[1:], [{"publicLinkEnabled": False}])
        self.assertFalse(fake.group["attributes"]["publicLinkEnabled"])
        self.assertIn("link zustand=abgebrochen grund=limit", run.stdout)

    def assert_switched_back_off(self, fake, run):
        text = run.stdout + run.stderr
        self.assertEqual(run.returncode, 1, text)
        self.assertEqual(fake.patches()[-1], {"publicLinkEnabled": False})
        self.assertFalse(fake.group["attributes"]["publicLinkEnabled"])
        for forbidden in (LINK, "QWERTZ", GROUP_ID, "G-7c41", "APP1"):
            self.assertNotIn(forbidden, text)

    def test_malformed_readback_switches_back_off(self):
        for name, body in MALFORMED_READBACKS.items():
            with self.subTest(form=name):
                fake = self.fake(malformed_readback=body)
                run = self.link(fake)
                self.assert_switched_back_off(fake, run)
                self.assertEqual(len(fake.patches()), 2)
                self.assertIn("link zustand=abgebrochen grund=limit", run.stdout)
                self.assertIn("zusammenfassung geschrieben=2", run.stdout)

    def test_malformed_readback_after_failed_enable_switches_back_off(self):
        for name, body in MALFORMED_READBACKS.items():
            with self.subTest(form=name):
                fake = self.fake(error_after_enable=True, malformed_readback=body)
                run = self.link(fake)
                self.assert_switched_back_off(fake, run)  # der 500 wird wiederholt, ausgeschaltet wird genau einmal
                self.assertEqual(fake.patches().count({"publicLinkEnabled": False}), 1)
                self.assertIn("::error::", run.stdout)
                self.assertNotIn("eingeschaltet", run.stdout)

    def test_off_switches_link_off_and_is_idempotent(self):
        fake = self.fake()
        self.link(fake)
        run = self.link(fake, "--aus")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertEqual(fake.patches()[-1], {"publicLinkEnabled": False})
        self.assertIn("link zustand=ausgeschaltet", run.stdout)
        before = len(fake.patches())
        run = self.link(fake, "--aus")
        self.assertEqual((run.returncode, len(fake.patches())), (0, before))
        self.assertIn("link zustand=vorhanden aus", run.stdout)

    def test_unknown_argument_never_enables(self):
        for args in (("--AUS",), ("--off",), ("--aus", "--off")):
            with self.subTest(args=args):
                fake = self.fake()
                run = self.link(fake, *args)
                self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                self.assertEqual(fake.requests, [])
                self.assertIn("::error::", run.stdout)
                self.assertIn("--aus", run.stdout)
                self.assertIn("zusammenfassung geschrieben=0", run.stdout)
                self.assertNotIn("link zustand=", run.stdout)

    def test_off_with_odd_enabled_value_still_patches(self):
        for value in ("true", None, MISSING):
            with self.subTest(value=value):
                fake = self.fake(enabled=value)
                run = self.link(fake, "--aus")
                self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assertEqual(fake.patches(), [{"publicLinkEnabled": False}])
                self.assertIn("link zustand=ausgeschaltet", run.stdout)
                self.assertIn("zusammenfassung geschrieben=1", run.stdout)

    def test_failed_switch_back_off_is_loud(self):
        for kwargs in ({"ignore_limit": True}, {"break_reads_after_patch": True}):
            with self.subTest(**kwargs):
                fake = self.fake(fail_off_patch=403, **kwargs)
                run = self.link(fake)
                text = run.stdout + run.stderr
                self.assertEqual(run.returncode, 1, text)
                self.assertEqual(fake.patches()[-1], {"publicLinkEnabled": False})
                self.assertIn("link zustand=ausschalten-gescheitert grund=", run.stdout)
                self.assertIn("::error::", run.stdout)
                self.assertNotIn("abgebrochen", text)
                self.assertNotIn("eingeschaltet", text)
                for forbidden in (LINK, "QWERTZ", GROUP_ID, "G-7c41", "APP1"):
                    self.assertNotIn(forbidden, text)

    def test_missing_group_aborts_before_any_write(self):
        fake = self.fake(group_present=False)
        run = self.link(fake)
        self.assertEqual(run.returncode, 1)
        self.assertIn("::error::", run.stdout)
        self.assertEqual(fake.patches(), [])

    def test_forbidden_and_other_errors_are_reported(self):
        fake = self.fake(fail_patch=(403, "FORBIDDEN_ERROR"))
        run = self.link(fake)
        self.assertEqual(run.returncode, 1)
        self.assertIn("Schlüssel ohne Schreibrecht", run.stdout + run.stderr)
        self.assertEqual(len(fake.patches()), 1)
        fake = self.fake(fail_patch=(422, "ENTITY_UNPROCESSABLE"))
        run = self.link(fake)
        self.assertEqual(run.returncode, 1)
        self.assertIn("::error::", run.stdout)
        self.assertEqual(len(fake.patches()), 1)

    def test_server_error_on_enable_still_switches_off(self):
        fake = self.fake(error_after_enable=True)
        run = self.link(fake)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertEqual(fake.patches()[-1], {"publicLinkEnabled": False})
        self.assertFalse(fake.group["attributes"]["publicLinkEnabled"])
        self.assertIn("::error::", run.stdout)
        text = run.stdout + run.stderr
        for forbidden in (LINK, "QWERTZ", GROUP_ID, "G-7c41", "APP1"):
            self.assertNotIn(forbidden, text)

    def test_output_has_only_state_words(self):
        for args in ((), ("--aus",)):
            fake = self.fake()
            run = self.link(fake)
            if args:
                run = self.link(fake, *args)
            text = run.stdout + run.stderr
            for forbidden in (LINK, "QWERTZ", GROUP_ID, "G-7c41", "APP1", "B-91f3", "4711", "4712", "BEGIN"):
                self.assertNotIn(forbidden, text, args)
            self.assertIn("link zustand=", text)


class WorkflowTests(unittest.TestCase):
    def test_workflow_file(self):
        workflow = WORKFLOW.read_text()
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        for needle in ("- link\n", "- link-aus", "inputs.aktion == 'link'", "needs.link.result"):
            self.assertIn(needle, workflow)
        link = workflow.split("\n  link:", 1)[1].split("\n  probe:", 1)[0]
        for needle in ("umask 077", "rm -f", "runs-on: ubuntu-latest"):
            self.assertIn(needle, link)
        steps = [step for step in link.split("\n      - ")[1:] if "asc_beta_link.py" in step]
        self.assertEqual(len(steps), 2, steps)
        by_condition = {}
        for step in steps:
            condition = [line.strip() for line in step.splitlines() if line.strip().startswith("if:")]
            self.assertEqual(len(condition), 1, step)
            by_condition[condition[0]] = step
        self.assertEqual(set(by_condition), {"if: ${{ inputs.aktion == 'link' }}", "if: ${{ inputs.aktion == 'link-aus' }}"})
        on, off = by_condition["if: ${{ inputs.aktion == 'link' }}"], by_condition["if: ${{ inputs.aktion == 'link-aus' }}"]
        self.assertIn("scripts/asc_beta_link.py --aus", off)
        self.assertIn("scripts/asc_beta_link.py", on)
        self.assertNotIn("--aus", on)
        for step in (on, off):
            self.assertIn("umask 077", step)
            self.assertIn("rm -f", step)
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))
        for forbidden in ("publicLinkEnabled", "betaAppReviewSubmissions"):
            self.assertNotIn(forbidden, workflow)
        self.assertNotIn("asc_beta_link", (WORKFLOWS / "testflight.yml").read_text())

    def test_invite_script_untouched(self):
        text = INVITE.read_text()
        for forbidden in ('"PATCH"', "'PATCH'", '"publicLinkEnabled": True', "publicLinkLimit"):
            self.assertNotIn(forbidden, text)

    def test_testflight_doc_lists_link_row(self):
        lines = DOC.read_text().splitlines()
        review = [line for line in lines if line.startswith("| Beta-Review")]
        self.assertTrue(review and "APPROVED" in review[0] and "41019692346" in review[0], review)
        row = [line for line in lines if line.startswith("| Öffentlicher Link")]
        self.assertTrue(row and "offen" in row[0] and "#743" in row[0], row)
        text = "\n".join(lines)
        self.assertIn("aktion=link", text)
        self.assertIn("link-aus", text)
        section = text.split("**Handlauf `link`", 1)[1].split("\n**", 1)[0]
        fallback = [line for line in section.splitlines() if line.startswith("- Rückfall")]
        self.assertTrue(fallback, section)
        self.assertIn("App Store Connect", section[section.index("- Rückfall"):])


if __name__ == "__main__":
    unittest.main()
