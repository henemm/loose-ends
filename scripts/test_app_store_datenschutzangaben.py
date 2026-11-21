"""Hält die Fragebogen-Vorlage für Apples Datenschutz-Etikett gleich der einen Quelle (#625 S3).

Die Vorlage `docs/reference/app-store-datenschutzangaben.md` führt im Abschnitt
„Antworten mit Konto“ eine Tabelle der Datentypen, die bei eingeschaltetem Konto bei Apple
anzugeben sind. Diese Tabelle muss `ACCOUNT_TYPES` aus `scripts/privacy_manifest.py` folgen:
gleiche Schlüssel, Verknüpft, Tracking und Zwecke. Negativtests arbeiten auf einer im Speicher
geänderten Kopie des Vorlagentextes, nie auf der Datei.
"""

import os
import re
import unittest

from privacy_manifest import ACCOUNT_TYPES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, "docs", "reference", "app-store-datenschutzangaben.md")

SECTION = "Antworten mit Konto"
SECTIONS = [
    "Stand heute",
    "Antworten mit Konto",
    "Bewusst nicht angegeben",
    "Zeitpunkt und Ablauf",
    "Quellen",
]
HEADER = [
    "Manifest-Schlüssel",
    "Apple-Typ (ASC, englisch)",
    "Verknüpft",
    "Tracking",
    "Zweck",
    "Beleg im Code",
]
IP_QUOTE = (
    "Declare the relevant data types based on how you use IP address, such as precise "
    "location, coarse location, device ID, or diagnostics."
)
SOURCE_URL = "https://developer.apple.com/support/app-privacy-on-the-app-store"
USER_ID = "NSPrivacyCollectedDataTypeUserID"


class TemplateError(Exception):
    pass


def headings(text):
    """Die `##`-Überschriften des Textes in ihrer Reihenfolge."""
    return [line[3:].strip() for line in text.splitlines() if line.startswith("## ")]


def section(text, name):
    """Die Zeilen eines `##`-Abschnitts bis zur nächsten `##`-Überschrift."""
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip() == f"## {name}"), None)
    if start is None:
        raise TemplateError(f"Abschnitt '## {name}' fehlt")
    body = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        body.append(line)
    return body


def cells(line):
    """Die Zellen einer Tabellenzeile ohne die äußeren Striche."""
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def yes_no(value, key, column):
    if value == "ja":
        return True
    if value == "nein":
        return False
    raise TemplateError(f"{key}: {column} muss 'ja' oder 'nein' sein, nicht '{value}'")


def parse_row(row):
    """Eine Tabellenzeile als (Schlüssel, verknüpft, Tracking, Zwecke)."""
    if len(row) != len(HEADER):
        raise TemplateError(f"Zeile mit {len(row)} statt {len(HEADER)} Spalten: {row}")
    key = row[0].strip("`")
    linked = yes_no(row[2], key, "Verknüpft")
    tracking = yes_no(row[3], key, "Tracking")
    purposes = [p.strip().strip("`") for p in row[4].split(",") if p.strip()]
    return key, linked, tracking, purposes


def parse_types(text):
    """Die Typ-Tabelle aus „Antworten mit Konto“; wirft bei jeder Formabweichung."""
    table = [line for line in section(text, SECTION) if line.strip().startswith("|")]
    if not table:
        raise TemplateError(f"Abschnitt '## {SECTION}' enthält keine Tabelle")
    if cells(table[0]) != HEADER:
        raise TemplateError(f"Kopfzeile weicht ab: {cells(table[0])} statt {HEADER}")
    rows = [cells(line) for line in table[1:]]
    rows = [row for row in rows if not all(re.fullmatch(r":?-+:?", c) for c in row)]
    return [parse_row(row) for row in rows]


def findings(types, account_types=ACCOUNT_TYPES):
    """Abweichungen der Tabelle von ACCOUNT_TYPES, je mit dem betroffenen Schlüssel."""
    expected = {item["NSPrivacyCollectedDataType"]: item for item in account_types}
    seen, result = set(), []
    for key, linked, tracking, purposes in types:
        if key in seen:
            result.append(f"{key}: doppelt in der Tabelle")
        seen.add(key)
        item = expected.get(key)
        if item is None:
            result.append(f"{key}: nicht in ACCOUNT_TYPES")
            continue
        if linked != item["NSPrivacyCollectedDataTypeLinked"]:
            result.append(f"{key}: Verknüpft weicht ab")
        if tracking != item["NSPrivacyCollectedDataTypeTracking"]:
            result.append(f"{key}: Tracking weicht ab")
        if purposes != item["NSPrivacyCollectedDataTypePurposes"]:
            result.append(f"{key}: Zweck weicht ab")
    result += [f"{key}: fehlt in der Tabelle" for key in expected if key not in seen]
    return result


def read_template():
    with open(TEMPLATE, encoding="utf-8") as handle:
        return handle.read()


def row_line(text, key):
    """Die Tabellenzeile der Vorlage, die mit dem Schlüssel beginnt."""
    for line in section(text, SECTION):
        if line.strip().startswith(f"| `{key}`"):
            return line
    raise AssertionError(f"Zeile für {key} fehlt in der Vorlage")


def replace_cell(line, index, value):
    row = cells(line)
    row[index] = value
    return "| " + " | ".join(row) + " |"


class TemplateFollowsManifestTests(unittest.TestCase):
    """AC-1, AC-5: die echte Vorlage."""

    def setUp(self):
        self.text = read_template()

    def test_sections_in_order(self):
        self.assertEqual(headings(self.text), SECTIONS)

    def test_today_names_data_not_collected(self):
        today = "\n".join(section(self.text, "Stand heute"))
        self.assertIn("Data Not Collected", today)
        self.assertIn("app-weit", today)

    def test_table_equals_account_types(self):
        types = parse_types(self.text)
        self.assertEqual(len(types), len(ACCOUNT_TYPES))
        self.assertEqual(findings(types), [])

    def test_ip_point_quotes_apple_and_names_retention(self):
        omitted = " ".join(" ".join(section(self.text, "Bewusst nicht angegeben")).split())
        self.assertIn(IP_QUOTE, omitted)
        self.assertIn("kein eigener Typ", omitted)
        self.assertIn("14 Tage", omitted)

    def test_sources_name_apple_page(self):
        self.assertIn(SOURCE_URL, "\n".join(section(self.text, "Quellen")))


class MutatedTemplateTests(unittest.TestCase):
    """AC-6: jede Abweichung von ACCOUNT_TYPES fällt auf und nennt den Schlüssel."""

    def setUp(self):
        self.text = read_template()
        self.line = row_line(self.text, USER_ID)

    def assertFindingNames(self, text, key):
        result = findings(parse_types(text))
        self.assertTrue(result, "Abweichung wurde nicht erkannt")
        self.assertTrue(any(key in item for item in result), result)

    def test_missing_row(self):
        self.assertFindingNames(self.text.replace(self.line + "\n", ""), USER_ID)

    def test_extra_row(self):
        extra = self.line.replace(USER_ID, "NSPrivacyCollectedDataTypeEmailAddress")
        text = self.text.replace(self.line, self.line + "\n" + extra)
        self.assertFindingNames(text, "NSPrivacyCollectedDataTypeEmailAddress")

    def test_doubled_row(self):
        self.assertFindingNames(self.text.replace(self.line, self.line + "\n" + self.line), USER_ID)

    def test_linked_changed(self):
        self.assertFindingNames(self.text.replace(self.line, replace_cell(self.line, 2, "nein")), USER_ID)

    def test_tracking_changed(self):
        self.assertFindingNames(self.text.replace(self.line, replace_cell(self.line, 3, "ja")), USER_ID)

    def test_purpose_changed(self):
        other = "`NSPrivacyCollectedDataTypePurposeAnalytics`"
        self.assertFindingNames(self.text.replace(self.line, replace_cell(self.line, 4, other)), USER_ID)


class BrokenTemplateTests(unittest.TestCase):
    """AC-7: eine kaputte Form wirft, statt still leer durchzugehen."""

    def setUp(self):
        self.text = read_template()
        self.body = "\n".join(section(self.text, SECTION))

    def test_missing_section(self):
        text = self.text.replace(f"## {SECTION}", "## Etwas anderes")
        with self.assertRaisesRegex(TemplateError, SECTION):
            parse_types(text)

    def test_missing_table(self):
        body = "\n".join(l for l in self.body.splitlines() if not l.strip().startswith("|"))
        with self.assertRaisesRegex(TemplateError, "keine Tabelle"):
            parse_types(self.text.replace(self.body, body))

    def test_header_changed(self):
        text = self.text.replace("| Verknüpft |", "| Verbunden |", 1)
        with self.assertRaisesRegex(TemplateError, "Kopfzeile"):
            parse_types(text)

    def test_value_not_yes_no(self):
        line = row_line(self.text, USER_ID)
        text = self.text.replace(line, replace_cell(line, 2, "vielleicht"))
        with self.assertRaisesRegex(TemplateError, USER_ID):
            parse_types(text)


if __name__ == "__main__":
    unittest.main()
