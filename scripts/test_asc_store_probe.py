"""Tests für asc_store_probe.py (#837 Schnitt 1): welche App-Info ist beschreibbar.

Aufruf: python3 scripts/test_asc_store_probe.py
Gegen den lokalen Nachbau aus test_asc_beta_probe.py. Zeilenformat:
`appinfo nr=<n> state=<Wert|?> appStoreState=<Wert|?> felder=<Namen> relationen=<Namen>`
`untertitel appinfo=<n> sprache=… name=… untertitel=… zeichen=…` bzw. `untertitel appinfo=<n> keine`
(Antwort leer) oder `untertitel appinfo=<n> fehler` (Abfrage gescheitert); ohne App-Info `appinfo keine`.
"""
import subprocess
import sys
import unittest
from pathlib import Path

import test_asc_beta_probe as beta

SCRIPT = Path(__file__).resolve().parent / "asc_store_probe.py"

INFOS = {"data": [
    {"id": "I1", "attributes": {"state": "READY_FOR_DISTRIBUTION", "zebra": "x", "alpha": "y"},
     "relationships": {"primaryCategory": {}, "ageRatingDeclaration": {}}},
    {"id": "I2", "attributes": {"appStoreState": "IN_REVIEW"},
     "relationships": {"appInfoLocalizations": {}}},
]}


def loc(locale, name, subtitle):
    return {"data": [{"id": "L", "attributes": {"locale": locale, "name": name, "subtitle": subtitle}}]}


def routes(first=None, second=None, second_status=200, infos=None):
    return {
        "/v1/apps?": (200, {"data": [{"id": "APP1"}]}),
        "/v1/apps/APP1/appInfos": (200, INFOS if infos is None else infos),
        "/v1/appInfos/I1/appInfoLocalizations": (200, first or loc("de-DE", "Loose Ends", "Sortiert")),
        "/v1/appInfos/I2/appInfoLocalizations": (second_status,
                                                 second or loc("de-DE", "Loose Ends", "Einfach sagen.")),
        "/v1/apps/APP1/appStoreVersions": (200, {"data": []}),
    }


class StoreProbeTests(unittest.TestCase):
    def setUp(self):
        self.helper = beta.ProbeTests("test_everything_present")
        self.helper.setUp()
        self.addCleanup(self.helper.tearDown)

    def run_probe(self, **kwargs):
        fake = beta.FakeASC(routes=routes(**kwargs))
        self.addCleanup(fake.close)
        helper = self.helper
        import os
        env = dict(os.environ, ASC_KEY_ID="K", ASC_ISSUER_ID="I", ASC_KEY_FILE=str(helper.key),
                   ASC_API_BASE=fake.base, ASC_POLL_SECONDS="0", ASC_TIMEOUT_SECONDS="2", ASC_PLATFORM="")
        result = subprocess.run([sys.executable, str(SCRIPT)], env=env, capture_output=True, text=True,
                                timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return fake, result

    @staticmethod
    def lines(result, prefix):
        return [line for line in result.stdout.splitlines() if line.startswith(prefix)]

    def test_appinfo_line_has_both_states_separately(self):
        _, result = self.run_probe()
        first, second = self.lines(result, "appinfo nr=1 "), self.lines(result, "appinfo nr=2 ")
        self.assertEqual((len(first), len(second)), (1, 1), result.stdout)
        self.assertIn("state=READY_FOR_DISTRIBUTION appStoreState=? ", first[0])
        self.assertIn("state=? appStoreState=IN_REVIEW ", second[0])

    def test_appinfo_line_lists_attribute_and_relationship_names_sorted(self):
        _, result = self.run_probe()
        line, = self.lines(result, "appinfo nr=1 ")
        self.assertIn("felder=alpha,state,zebra", line)
        self.assertIn("relationen=ageRatingDeclaration,primaryCategory", line)
        self.assertNotIn("zebra=x", line)

    def test_subtitle_lines_carry_appinfo_number(self):
        _, result = self.run_probe()
        lines = self.lines(result, "untertitel ")
        self.assertEqual(len(lines), 2, result.stdout)
        self.assertTrue(lines[0].startswith("untertitel appinfo=1 sprache=de-DE"), lines)
        self.assertIn("untertitel=Sortiert zeichen=8", lines[0])
        self.assertTrue(lines[1].startswith("untertitel appinfo=2 sprache=de-DE"), lines)
        self.assertIn("zeichen=14", lines[1])
        self.assertFalse(any(" info=" in line for line in lines), lines)

    def test_appinfo_without_localization_says_keine(self):
        _, result = self.run_probe(second={"data": []})
        self.assertIn("untertitel appinfo=2 keine", result.stdout.splitlines())

    def test_failed_localization_query_says_fehler_not_keine(self):
        _, result = self.run_probe(second_status=500)
        lines = self.lines(result, "untertitel appinfo=2 ")
        self.assertEqual(lines, ["untertitel appinfo=2 fehler"], result.stdout)

    def test_empty_subtitle_says_keiner(self):
        _, result = self.run_probe(first=loc("en-US", "Loose Ends", ""))
        line, = self.lines(result, "untertitel appinfo=1 ")
        self.assertIn("untertitel=keiner zeichen=0", line)

    def test_no_appinfo_says_appinfo_keine(self):
        _, result = self.run_probe(infos={"data": []})
        self.assertIn("appinfo keine", result.stdout.splitlines())
        self.assertFalse(self.lines(result, "untertitel "), result.stdout)

    def test_probe_never_writes(self):
        fake, _ = self.run_probe()
        self.assertTrue(fake.requests)
        self.assertEqual({method for method, _ in fake.requests}, {"GET"})

    def test_summary_line_still_present(self):
        _, result = self.run_probe()
        lines = result.stdout.splitlines()
        self.assertTrue(lines[-1].startswith("zusammenfassung antworten="), lines[-1])
        self.assertEqual(len(self.lines(result, "zusammenfassung")), 1)
        self.assertEqual(lines[-1], "zusammenfassung antworten=4 von=4 befunde=0")


if __name__ == "__main__":
    unittest.main()
