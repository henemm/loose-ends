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


def routes(first=None, second=None, second_status=200, infos=None, extra=None):
    return {
        "/v1/apps?": (200, {"data": [{"id": "APP1"}]}),
        "/v1/apps/APP1/appInfos": (200, INFOS if infos is None else infos),
        "/v1/appInfos/I1/appInfoLocalizations": (200, first or loc("de-DE", "Loose Ends", "Sortiert")),
        "/v1/appInfos/I2/appInfoLocalizations": (second_status,
                                                 second or loc("de-DE", "Loose Ends", "Einfach sagen.")),
        "/v1/apps/APP1/appStoreVersions": (200, {"data": []}),
        **(extra or {}),
    }


class ProbeCase(unittest.TestCase):
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


class StoreProbeTests(ProbeCase):
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


VERSION = {"data": [{"id": "V1", "attributes": {"versionString": "1.0.1", "platform": "IOS",
                                                  "appStoreState": "PREPARE_FOR_SUBMISSION"}}]}
LABEL = "1.0.1/IOS/PREPARE_FOR_SUBMISSION"
DESCRIPTION = "Erste Zeile.\nZweite Zeile mit Ärger und Übung. " + "x" * 70
KEYWORDS = "k" * 60


def version_locales(de=None, en=None):
    de = {"locale": "de-DE", "description": DESCRIPTION, "keywords": KEYWORDS,
          "supportUrl": "https://example.org/hilfe"} if de is None else de
    en = {"locale": "en-US"} if en is None else en
    return {"data": [{"id": "LDE", "attributes": de}, {"id": "LEN", "attributes": en}]}


def store_routes(de=None, en=None, placements=None, refdata=None):
    """Eine Version mit de-DE und en-US; `placements` und `refdata` sind (Status, Rumpf)."""
    base = "/v1/appStoreVersionLocalizations"
    found = {
        "/v1/apps/APP1/appStoreVersions": (200, VERSION),
        "/v1/appStoreVersions/V1/appStoreVersionLocalizations": (200, version_locales(de, en)),
        f"{base}/LDE/appScreenshotSets": (200, {"data": []}),
        f"{base}/LEN/appScreenshotSets": (200, {"data": []}),
        f"{base}/LDE/appAssetLibraryPlacements": (200, {"data": [
            {"id": "P1", "attributes": {"placementGroup": "IPHONE_67", "placementType": "SCREENSHOT",
                                        "state": "COMPLETE"}},
            {"id": "P2", "attributes": {"placementGroup": "IPAD_13"}}]}),
        f"{base}/LEN/appAssetLibraryPlacements": (200, {"data": []}),
        "/v1/appAssetLibraryRefData": (200, {"data": [
            {"id": "R1", "attributes": {"placementGroup": "WATCH_ULTRA"}},
            {"id": "R2", "attributes": {"placementGroup": "IPAD_13"}},
            {"id": "R3", "attributes": {"placementGroup": "IPHONE_67"}}]}),
    }
    if placements is not None:
        found[f"{base}/LDE/appAssetLibraryPlacements"] = placements
    if refdata is not None:
        found["/v1/appAssetLibraryRefData"] = refdata
    return found


class StoreTextTests(ProbeCase):
    """Schnitt 1 von #842: Texte und Bildplatzierungen der Versions-Lokalisierung (nur lesen)."""

    def probe(self, **kwargs):
        return self.run_probe(extra=store_routes(**kwargs))

    def line(self, result, prefix):
        lines = self.lines(result, prefix)
        self.assertEqual(len(lines), 1, f"{prefix!r}: {result.stdout}")
        return lines[0]

    def test_text_line_counts_each_field(self):
        fake, result = self.probe()
        line = self.line(result, f"text version={LABEL} sprache=de-DE ")
        self.assertIn(f"beschreibung={len(DESCRIPTION)} schluesselwoerter=60 "
                      "supporturl=https://example.org/hilfe werbetext=0 marketingurl=keine", line)

    def test_description_printed_on_one_line_with_umlauts(self):
        _, result = self.probe()
        line = self.line(result, f"beschreibung version={LABEL} sprache=de-DE ")
        self.assertIn("Ärger und Übung", line)
        self.assertIn("Erste Zeile.\\nZweite Zeile", line)
        self.assertNotIn("\n", line)
        self.assertIn(f"zeichen={len(DESCRIPTION)}", line)

    def test_empty_en_us_localization_says_keiner(self):
        _, result = self.probe()
        text = self.line(result, f"text version={LABEL} sprache=en-US ")
        self.assertIn("beschreibung=0 schluesselwoerter=0 supporturl=keine werbetext=0 marketingurl=keine", text)
        for field in ("beschreibung", "schluesselwoerter", "werbetext"):
            line = self.line(result, f"{field} version={LABEL} sprache=en-US ")
            self.assertIn("text=keiner", line)
            self.assertIn("zeichen=0", line)

    def test_placement_lines_per_localization(self):
        _, result = self.probe()
        lines = self.lines(result, f"platzierung version={LABEL} sprache=de-DE ")
        self.assertEqual(len(lines), 2, result.stdout)
        self.assertIn("gruppe=IPHONE_67 typ=SCREENSHOT zustand=COMPLETE", lines[0])
        self.assertIn("gruppe=IPAD_13 typ=? zustand=?", lines[1])
        self.assertIn(f"platzierung keine version={LABEL} sprache=en-US", result.stdout.splitlines())

    def test_placement_error_does_not_abort(self):
        _, result = self.probe(placements=(404, {}))
        self.assertIn(f"platzierung fehler version={LABEL} sprache=de-DE", result.stdout.splitlines())
        self.assertTrue(self.lines(result, f"text version={LABEL} sprache=en-US "), result.stdout)
        self.assertEqual(len(self.lines(result, "zusammenfassung")), 1)

    def test_refdata_group_names_sorted(self):
        _, result = self.probe()
        self.assertIn("refdaten gruppen=IPAD_13,IPHONE_67,WATCH_ULTRA", result.stdout.splitlines())
        _, none = self.probe(refdata=(200, {"data": [{"id": "R", "attributes": {"x": 1}}]}))
        self.assertIn("refdaten keine", none.stdout.splitlines())
        _, failed = self.probe(refdata=(404, {}))
        self.assertIn("refdaten fehler", failed.stdout.splitlines())

    def test_probe_never_writes_and_keeps_old_lines(self):
        fake, result = self.probe()
        self.assertEqual({method for method, _ in fake.requests}, {"GET"})
        self.assertTrue(self.lines(result, "untertitel "), result.stdout)
        self.assertTrue(self.lines(result, "bildsatz keine "), result.stdout)
        self.assertTrue(self.lines(result, "platzierung "), result.stdout)
        self.assertEqual(len(self.lines(result, "zusammenfassung antworten=")), 1)


if __name__ == "__main__":
    unittest.main()
