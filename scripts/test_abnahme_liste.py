"""Prüfliste der TestFlight-Abnahme (#176): Aufbau und Belegangaben von docs/reference/abnahme-testflight.md.

Der Test beweist nur die Form der Liste (Status, Ticket, Build, Beleg-Dateien), nicht, dass die Schritte auf
Hennings Geräten laufen. Gerätepunkte stehen als „wartet auf Hennings Wort“.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIST = ROOT / "docs/reference/abnahme-testflight.md"
COLUMNS = ["Nr", "Schritt", "Bedienweg", "Quelle", "Status", "Beleg", "Build"]
STATUS = {"belegt", "Lücke", "wartet auf Hennings Wort"}
PROOF_DIR = "docs/artifacts/176-abnahme/"
NONE = "–"


def cells(line: str):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def load_text() -> str:
    if not LIST.exists():
        raise AssertionError(f"{LIST.relative_to(ROOT)} fehlt")
    return LIST.read_text(encoding="utf-8")


def parse_table(text: str):
    """Kopfzeile und Zeilen der Tabelle „Prüfliste“ (die erste Tabelle mit Spalte Nr)."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.lstrip().startswith("|") and cells(line)[:1] == ["Nr"]:
            header = cells(line)
            rows = []
            for row in lines[i + 2:]:
                if not row.lstrip().startswith("|"):
                    break
                rows.append(dict(zip(header, cells(row))))
            return header, rows
    raise AssertionError("keine Tabelle mit Spalte „Nr“ gefunden")


def check_rows(rows, root=ROOT):
    """Eine Fehlermeldung je Verstoß, mit Nr und Grund."""
    errors = []
    seen = set()
    for r in rows:
        nr = r.get("Nr", "?")
        if not re.fullmatch(r"S\d{2}", nr) or nr in seen:
            errors.append(f"{nr}: Nr ungültig oder doppelt")
        seen.add(nr)
        for col in ("Schritt", "Bedienweg", "Quelle"):
            if not r.get(col):
                errors.append(f"{nr}: Spalte {col} leer")
        status, proof, build = r.get("Status", ""), r.get("Beleg", ""), r.get("Build", "")
        if status not in STATUS:
            errors.append(f"{nr}: Status „{status}“ nicht erlaubt")
        elif status == "belegt":
            if not re.search(r"#\d+", proof):
                errors.append(f"{nr}: belegt ohne Ticket im Beleg")
            if not (build.isdigit() and int(build) > 0):
                errors.append(f"{nr}: belegt ohne Buildnummer")
        elif proof != NONE or build != NONE:
            errors.append(f"{nr}: {status} darf weder Beleg noch Build tragen")
        for path in re.findall(r"`(" + re.escape(PROOF_DIR) + r"[^`]+)`", proof):
            if not (pathlib.Path(root) / path).exists():
                errors.append(f"{nr}: Beleg-Datei {path} fehlt")
    return errors


class AbnahmeListeTests(unittest.TestCase):
    def rows(self):
        return parse_table(load_text())[1]

    def test_list_exists_and_has_seven_columns(self):
        header, rows = parse_table(load_text())
        self.assertEqual(header, COLUMNS)
        self.assertGreaterEqual(len(rows), 12)

    def test_numbers_are_unique(self):
        nrs = [r["Nr"] for r in self.rows()]
        self.assertEqual(len(nrs), len(set(nrs)))
        self.assertTrue(all(re.fullmatch(r"S\d{2}", n) for n in nrs), nrs)

    def test_status_is_allowed(self):
        self.assertEqual([r["Nr"] for r in self.rows() if r["Status"] not in STATUS], [])

    def test_belegt_names_ticket_and_build(self):
        for r in self.rows():
            if r["Status"] == "belegt":
                self.assertRegex(r["Beleg"], r"#\d+", r["Nr"])
                self.assertTrue(r["Build"].isdigit() and int(r["Build"]) > 0, r["Nr"])

    def test_gap_and_waiting_have_no_proof(self):
        for r in self.rows():
            if r["Status"] in ("Lücke", "wartet auf Hennings Wort"):
                self.assertEqual((r["Beleg"], r["Build"]), (NONE, NONE), r["Nr"])

    def test_proof_files_exist(self):
        self.assertEqual(check_rows(self.rows()), [])

    def test_required_gap_steps_present(self):
        for ticket in ("#607", "#584", "#601", "#605"):
            hits = [r for r in self.rows() if ticket in " ".join(r.values())]
            self.assertTrue(hits, f"{ticket} fehlt in der Liste")
            self.assertTrue(all(r["Status"] != "belegt" for r in hits), f"{ticket} darf nicht belegt sein")

    def test_required_coverage(self):
        text = " ".join(r["Schritt"] + " " + r["Bedienweg"] for r in self.rows())
        for word in ("iPad", "Mac", "Ortserinnerung"):
            self.assertIn(word, text)

    def test_every_row_has_source(self):
        for r in self.rows():
            for col in ("Schritt", "Bedienweg", "Quelle"):
                self.assertTrue(r[col], f"{r['Nr']}: {col} leer")

    def test_pruefblock_lists_all_gaps(self):
        text = load_text()
        self.assertEqual(len(re.findall(r"^#+\s*Prüfblock", text, re.M)), 1)
        block = re.split(r"^#+\s*Prüfblock", text, flags=re.M)[1]
        for r in self.rows():
            if r["Status"] in ("Lücke", "wartet auf Hennings Wort"):
                self.assertIn(r["Nr"], block, f"{r['Nr']} fehlt im Prüfblock")

    def test_checker_rejects_bad_rows(self):
        ok = {"Nr": "S01", "Schritt": "a", "Bedienweg": "b", "Quelle": "c", "Status": "belegt", "Beleg": "#1", "Build": "5"}
        bad = [
            dict(ok, Nr="S02", Status="fertig"),
            dict(ok, Nr="S03", Build=NONE),
            dict(ok, Nr="S04", Status="Lücke", Beleg=NONE, Build="5"),
            dict(ok, Nr="S05", Beleg="#1 `" + PROOF_DIR + "gibt-es-nicht.png`"),
        ]
        self.assertEqual(check_rows([ok]), [])
        for row in bad:
            errors = check_rows([row])
            self.assertTrue(errors and errors[0].startswith(row["Nr"]), (row["Nr"], errors))


if __name__ == "__main__":
    unittest.main()
