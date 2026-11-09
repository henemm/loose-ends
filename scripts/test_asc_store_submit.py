"""Tests für asc_store_submit.py und .github/workflows/asc-store-submit.yml (#893 Schnitt A).

Aufruf: python3 scripts/test_asc_store_submit.py
Gegen den Nachbau aus test_asc_store_version.py, ergänzt um `GET /v1/reviewSubmissions` (Filter `app` und `platform`,
je Zeile `platform` und `state`). Geprüft wird die Vorprüfung beider Plattformen: Version, Bau, Texte, Bilder,
Review-Detail und Einreichungen, nur GET, ohne Kennungen, Rohantwort oder Wortlaut in der Ausgabe. Ob Apple die
Liste der Einreichungen so liefert, zeigt nur der echte Handlauf nach dem Merge (Definition of Done).
"""
import os
import re
import subprocess
import sys
import tempfile
import unittest
import urllib.parse
from pathlib import Path

from test_asc_store_version import (EDITABLE, IOS_133, IOS_LIVE, IOS_NEW, MAC_133, MAC_LIVE, MAC_NEW, RAW_SECRET,
                                    FakeASC, build, loc, version)

SCRIPTS = Path(__file__).resolve().parent
SCRIPT = SCRIPTS / "asc_store_submit.py"
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "asc-store-submit.yml"
STORE_VERSION = SCRIPTS / "asc_store_version.py"
STORE_VERSION_TEST = SCRIPTS / "test_asc_store_version.py"

WORDING = "Wortlaut-im-Store-893"
USAGE = "::error::Aufruf: asc_store_submit.py pruefen"
IDS = r"\b(APP1|V[1-5]|BI\d+|BM\d+|L[2-5]|SUB-\d+|RD-\w+)\b"
FULL = {"description": WORDING + "-d", "keywords": WORDING + "-k", "supportUrl": "https://example.org/" + WORDING,
        "whatsNew": WORDING + "-w", "promotionalText": WORDING + "-p"}


def texts(**changes):
    values = dict(FULL, **changes)
    return {field: value for field, value in values.items() if value is not None}


def submission(sub_id, platform, state):
    attrs = {"platform": platform}
    if state is not None:
        attrs["state"] = state
    return {"id": sub_id, "type": "reviewSubmissions", "attributes": attrs}


class SubmitFakeASC(FakeASC):
    """Nachbau mit Einreichungen: `GET /v1/reviewSubmissions` filtert nach App und (abschaltbar) nach Plattform."""

    def __init__(self, *args, submissions=(), platform_filter=True, **kwargs):
        self.submissions = list(submissions)
        self.platform_filter = platform_filter
        super().__init__(*args, **kwargs)

    def read(self, path):
        url, _, query = path.partition("?")
        if url != "/v1/reviewSubmissions":
            return super().read(path)
        for suffix, status in self.get_fail.items():
            if url.endswith(suffix):
                return status, {"errors": [{"status": str(status), "detail": RAW_SECRET}]}
        params = urllib.parse.parse_qs(query)
        if params.get("filter[app]") != ["APP1"]:
            return 400, {"errors": [{"status": "400", "detail": RAW_SECRET}]}
        rows = self.submissions
        if self.platform_filter and "filter[platform]" in params:
            rows = [row for row in rows if row["attributes"]["platform"] in params["filter[platform]"]]
        return 200, {"data": rows}


def ready_state(**changes):
    """Beide Plattformen vollständig bereit: 1.0.1 bearbeitbar, Bau 133 gültig und zugeordnet, de-DE und en-US mit
    Texten, iOS mit Bildsätzen, Mac mit Platzierungen, Review-Detail für beide."""
    state = {
        "versions": (IOS_LIVE, IOS_NEW, MAC_LIVE, MAC_NEW),
        "builds": (IOS_133, MAC_133),
        "assigned": {"V2": "BI133", "V4": "BM133"},
        "localizations": {"V2": [loc("L2", "de-DE", **texts()), loc("L3", "en-US", **texts())],
                          "V4": [loc("L4", "de-DE", **texts()), loc("L5", "en-US", **texts())]},
        "sets": {"L2": [3], "L3": [2, 1]},
        "placements": {"L4": 4, "L5": 4},
        "review": {"V2", "V4"},
    }
    state.update(changes)
    return state


class StoreSubmitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.key = Path(self.tmp.name) / "key.p8"
        pem = Path(self.tmp.name) / "key.pem"
        subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", pem], check=True)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", pem, "-out", self.key], check=True)

    def fake(self, **changes):
        state = ready_state(**{key: value for key, value in changes.items() if key in ready_state()})
        extra = {key: value for key, value in changes.items() if key not in state}
        fake = SubmitFakeASC(state.pop("versions"), state.pop("builds"), **state, **extra)
        self.addCleanup(fake.close)
        return fake

    def run_script(self, fake, *args):
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(self.key), ASC_API_BASE=fake.base,
                   ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2")
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, text=True,
                              timeout=120)

    def pruefen(self, **changes):
        fake = self.fake(**changes)
        return fake, self.run_script(fake, "pruefen")

    def reasons(self, result, platform):
        prefix = f"{platform} nicht-bereit: "
        return [line[len(prefix):] for line in result.stdout.splitlines() if line.startswith(prefix)]

    def assert_ready(self, result, *platforms):
        for platform in platforms:
            self.assertIn(f"{platform} bereit", result.stdout.splitlines(), result.stdout + result.stderr)
            self.assertEqual(self.reasons(result, platform), [], result.stdout)

    def assert_reason(self, result, platform, *needles):
        """Eine Grund-Zeile der Plattform enthält alle Stücke; Ausgang 1 mit `::error::nicht bereit`."""
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("::error::nicht bereit", result.stdout)
        found = [line for line in self.reasons(result, platform) if all(needle in line for needle in needles)]
        self.assertTrue(found, f"{platform} ohne Grund {needles}:\n{result.stdout}")

    def assert_clean(self, result):
        output = result.stdout + result.stderr
        for secret in (RAW_SECRET, WORDING, "PRIVATE KEY", "Bearer", "eyJ"):
            self.assertNotIn(secret, output)
        self.assertNotRegex(output, IDS)

    # AC-1
    def test_ready_on_both_platforms_exit_zero(self):
        fake, result = self.pruefen()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")
        self.assertTrue(result.stdout.rstrip().endswith("zusammenfassung bereit=ios,mac nicht-bereit=keine"),
                        result.stdout)
        self.assertNotIn("::error::", result.stdout)
        queries = [urllib.parse.parse_qs(path.partition("?")[2]) for _, path, _ in fake.requests
                   if path.startswith("/v1/reviewSubmissions?")]
        self.assertEqual(sorted(query["filter[platform]"][0] for query in queries), ["IOS", "MAC_OS"])
        for query in queries:
            self.assertEqual(query["filter[app]"], ["APP1"])
        self.assert_clean(result)

    # AC-2
    def test_version_rules(self):
        _, result = self.pruefen(versions=(IOS_LIVE, IOS_NEW, MAC_LIVE))
        self.assert_reason(result, "MAC_OS", "bearbeitbare Versionen=0", "READY_FOR_SALE")
        _, result = self.pruefen(versions=(IOS_LIVE, IOS_NEW, version("V5", "IOS", EDITABLE, "1.0.2"), MAC_NEW))
        self.assert_reason(result, "IOS", "bearbeitbare Versionen=2")
        _, result = self.pruefen(versions=(IOS_NEW, version("V4", "MAC_OS", EDITABLE, "1.0.2")),
                                 builds=(IOS_133, build("BM133", "MAC_OS", "133", pre="1.0.2")))
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "1.0.1", "1.0.2")

    # AC-3
    def test_build_rules(self):
        cases = ((dict(assigned={"V2": "BI133"}), "kein Bau"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", state="PROCESSING"))),
                  "processingState PROCESSING"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", expired=True))), "abgelaufen"),
                 (dict(builds=(IOS_133, build("BM133", "MAC_OS", "133", pre="1.0"))), "vorabversion Soll 1.0.1 Ist 1.0"))
        for changes, needle in cases:
            with self.subTest(needle=needle):
                _, result = self.pruefen(**changes)
                self.assert_reason(result, "MAC_OS", needle)
                self.assert_ready(result, "IOS")

    # AC-4
    def test_text_rules(self):
        localized = ready_state()["localizations"]
        cases = (([loc("L2", "de-DE", **texts())], "en-US fehlt"),
                 ([loc("L2", "de-DE", **texts(whatsNew="")), localized["V2"][1]], "de-DE whatsNew leer"),
                 ([loc("L2", "de-DE", **texts(description=" \n\t ")), localized["V2"][1]], "de-DE description leer"),
                 ([localized["V2"][0], loc("L3", "en-US", **texts(keywords=None))], "en-US keywords leer"),
                 ([localized["V2"][0], loc("L3", "en-US", **texts(supportUrl=""))], "en-US supportUrl leer"))
        for rows, needle in cases:
            with self.subTest(needle=needle):
                _, result = self.pruefen(localizations={"V2": rows, "V4": localized["V4"]})
                self.assert_reason(result, "IOS", needle)
                self.assert_ready(result, "MAC_OS")
                self.assert_clean(result)
        _, result = self.pruefen(localizations={
            "V2": [loc("L2", "de-DE", **texts(promotionalText=None)), loc("L3", "en-US", **texts(promotionalText=""))],
            "V4": localized["V4"]})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")

    # AC-5
    def test_image_and_review_detail_rules(self):
        _, result = self.pruefen(sets={"L3": [2]}, placements={"L4": 4, "L5": 4})
        self.assert_reason(result, "IOS", "de-DE keine Bilder")
        self.assertFalse([line for line in self.reasons(result, "IOS") if "en-US" in line], result.stdout)
        self.assert_ready(result, "MAC_OS")
        _, result = self.pruefen(sets={"L2": [0], "L3": [1]})
        self.assert_reason(result, "IOS", "de-DE keine Bilder")
        _, result = self.pruefen(review={"V2"})
        self.assert_reason(result, "MAC_OS", "kein review-detail")
        self.assert_ready(result, "IOS")
        _, result = self.pruefen(sets={"L2": [1], "L3": [1], "L4": [2]}, placements={"L5": 1})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    # AC-6
    def test_submission_states(self):
        for state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING"):
            with self.subTest(state=state):
                _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", state)])
                self.assert_reason(result, "IOS", "belegt", state)
                self.assert_ready(result, "MAC_OS")
        for state, word in (("SOMETHING_NEW", "SOMETHING_NEW"), (None, "unbekannter Zustand")):
            with self.subTest(state=state):
                _, result = self.pruefen(submissions=[submission("SUB-2", "MAC_OS", state)])
                self.assert_reason(result, "MAC_OS", "belegt, unbekannter Zustand", word)
        _, result = self.pruefen(submissions=[submission("SUB-3", "IOS", "COMPLETE"),
                                              submission("SUB-4", "MAC_OS", "COMPLETE")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        _, result = self.pruefen(submissions=[submission("SUB-5", "MAC_OS", "IN_REVIEW")], platform_filter=False)
        self.assert_reason(result, "MAC_OS", "belegt", "IN_REVIEW")
        self.assert_ready(result, "IOS")

    # AC-7
    def test_ready_for_review_is_reusable_but_two_are_not(self):
        _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", "READY_FOR_REVIEW")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_ready(result, "IOS", "MAC_OS")
        self.assertIn("IOS hinweis: einreichung READY_FOR_REVIEW wiederverwendbar", result.stdout)
        _, result = self.pruefen(submissions=[submission("SUB-1", "IOS", "READY_FOR_REVIEW"),
                                              submission("SUB-2", "IOS", "READY_FOR_REVIEW")])
        self.assert_reason(result, "IOS", "READY_FOR_REVIEW", "mehrdeutig")
        self.assert_clean(result)

    # AC-8
    def test_both_platforms_fully_evaluated(self):
        _, result = self.pruefen(assigned={}, review=set(), submissions=[submission("SUB-1", "MAC_OS", "IN_REVIEW")])
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "kein Bau")
            self.assert_reason(result, platform, "kein review-detail")
        self.assert_reason(result, "MAC_OS", "belegt", "IN_REVIEW")
        self.assertIn("zusammenfassung bereit=keine nicht-bereit=ios,mac", result.stdout)
        self.assertIn("::error::nicht bereit: ios,mac", result.stdout)

    # AC-9
    def test_never_sends_non_get(self):
        for changes, code in (({}, 0), ({"assigned": {}}, 1)):
            plain = self.fake(**changes)
            refusing = self.fake(**changes, write_status=405)
            first, second = self.run_script(plain, "pruefen"), self.run_script(refusing, "pruefen")
            self.assertEqual(first.returncode, code, first.stdout + first.stderr)
            self.assertEqual(second.returncode, code, second.stdout + second.stderr)
            self.assertEqual(first.stdout, second.stdout)
            for fake in (plain, refusing):
                self.assertEqual(fake.writes(), [])
                self.assertTrue(fake.requests)
        source = SCRIPT.read_text()
        for needle in ("send_json", "POST", "PATCH", "DELETE"):
            self.assertNotIn(needle, source)

    # AC-10
    def test_output_has_no_ids_raw_answers_or_wording(self):
        _, result = self.pruefen(get_fail={"/V2/appStoreReviewDetail": 403, "/L3/appScreenshotSets": 500})
        self.assert_reason(result, "IOS", "nicht lesbar HTTP 403")
        self.assert_reason(result, "IOS", "nicht lesbar HTTP 500")
        self.assert_ready(result, "MAC_OS")
        self.assertIn("zusammenfassung bereit=mac nicht-bereit=ios", result.stdout)
        self.assert_clean(result)
        _, result = self.pruefen(get_fail={"/reviewSubmissions": 500})
        for platform in ("IOS", "MAC_OS"):
            self.assert_reason(result, platform, "nicht lesbar HTTP 500")
        self.assert_clean(result)

    # AC-11
    def test_bad_usage_makes_no_call(self):
        for args in ((), ("unbekannt",), ("einreichen",), ("pruefen", "einreichen")):
            with self.subTest(args=args):
                fake = self.fake()
                result = self.run_script(fake, *args)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(USAGE, result.stdout)
                self.assertEqual(fake.requests, [])

    # AC-13
    def test_store_version_script_untouched(self):
        self.assertNotIn("ubmission", STORE_VERSION.read_text())
        self.assertIn("def test_never_deletes_submits_or_writes_texts", STORE_VERSION_TEST.read_text())
        result = subprocess.run([sys.executable, str(STORE_VERSION_TEST)], capture_output=True, text=True,
                                timeout=600, cwd=SCRIPTS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class WorkflowTests(unittest.TestCase):
    # AC-12
    def test_workflow_offers_only_pruefen_and_hides_the_key(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("workflow_dispatch", workflow)
        for trigger in ("push:", "schedule:", "workflow_run:"):
            self.assertNotIn(trigger, workflow)
        self.assertIn("pull_request:", workflow)
        options = workflow[workflow.index("options:"):workflow.index("default:")]
        self.assertEqual(re.findall(r"-\s+(\S+)", options), ["pruefen"])
        self.assertNotIn("einreichen\n", workflow.replace("# ", ""))
        gate = "if: github.event_name == 'workflow_dispatch'"
        self.assertEqual(workflow.count(gate), 1)
        self.assertLess(workflow.index(gate), workflow.index("python3 scripts/asc_store_submit.py"))
        self.assertGreater(workflow.index("secrets."), workflow.index(gate))
        for needle in ("aktion:", "type: choice", "default: pruefen", "concurrency:", "group: asc-store-submit\n",
                       "cancel-in-progress: false", "umask 077", "trap", "rm -f", "timeout-minutes:",
                       "contents: read"):
            self.assertIn(needle, workflow)
        for path in ("scripts/asc_store_submit.py", "scripts/test_asc_store_submit.py",
                     ".github/workflows/asc-store-submit.yml", "scripts/asc_store_version.py",
                     "scripts/asc_version_texts.py", "scripts/asc_beta_invite.py"):
            self.assertIn(f"- {path}", workflow)
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
            self.assertIn(f"secrets.{name}", workflow)
        run_steps = [line for line in workflow.splitlines() if "python3 scripts/" in line]
        self.assertIn("python3 scripts/test_asc_store_submit.py", run_steps[0])
        self.assertLess(workflow.index("python3 scripts/test_asc_store_submit.py"),
                        workflow.index("python3 scripts/asc_store_submit.py"))
        self.assertEqual(workflow.count("inputs."), workflow.count("inputs.aktion"))
        for leak in ("cat \"$RUNNER_TEMP", "echo \"${{ secrets", "set -x"):
            self.assertNotIn(leak, workflow)


if __name__ == "__main__":
    unittest.main()
