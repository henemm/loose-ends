"""Belegprüfung für #625 S5d-2 (Store-Betrieb 1.0.2), AC-10, AC-11, AC-12, AC-13.

Läuft aus dem Repo-Wurzelordner:
    python3 -m unittest docs/artifacts/feat-625-s5d2-store-betrieb/test_belege.py -v

Belegformat (ein Markdown-Beleg je Schritt in diesem Ordner):
    acNN-<kurzname>.md, NN = 01 … 10
    eine Zeile `Zeit: <ISO-8601 mit Zone>` (Zeitpunkt des Schritts)
    schreibende Schritte: ein Abschnitt „lesen vorher“ und einer „Gegenprobe“
    ac10: genau eine Zeile `Zustand: a` (eingereicht nach Wort) oder `Zustand: b` (kein Wort)
"""

import re
import subprocess
import unittest
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TESTFLIGHT_DOC = ROOT / "docs" / "reference" / "testflight.md"

STEPS = range(1, 11)
# Schritte, die bei Apple oder am Dienst schreiben (AC-11: lesen vorher + Gegenprobe).
WRITING = {2, 3, 4, 6, 7, 8}
# Reihenfolge AC-11: 3 und 4 dürfen untereinander beliebig liegen.
ORDER = [[1], [2], [3, 4], [5], [6], [7], [8], [9], [10]]

SECRET_PATTERNS = {
    "privater Schlüssel": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "JWT": re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    "Apple-Konto-Kennung": re.compile(r"\b\d{6}\.[0-9a-f]{32}\.\d{4}\b"),
    "Bearer-Token": re.compile(r"(?i)bearer\s+[A-Za-z0-9._-]{20,}"),
}

FORBIDDEN_DIFF = [
    re.compile(r"\.swift$"),
    re.compile(r"(^|/)project\.yml$"),
    re.compile(r"Info\.plist$"),
    re.compile(r"\.entitlements$"),
    re.compile(r"PrivacyInfo\.xcprivacy$"),
    re.compile(r"^\.github/"),
    re.compile(r"^scripts/"),
]


def beleg(n):
    hits = sorted(HERE.glob(f"ac{n:02d}-*.md"))
    return hits[0] if len(hits) == 1 else None


def zeit(path):
    m = re.search(r"^Zeit:\s*(\S+)\s*$", path.read_text(encoding="utf-8"), re.M)
    if not m:
        return None
    raw = m.group(1).replace("Z", "+00:00")
    stamp = datetime.fromisoformat(raw)
    return stamp if stamp.tzinfo else None


class BelegeVorhanden(unittest.TestCase):
    def test_je_schritt_genau_ein_beleg(self):
        fehlend = [n for n in STEPS if beleg(n) is None]
        self.assertEqual(fehlend, [], f"Beleg fehlt oder ist doppelt für AC {fehlend}")

    def test_jeder_beleg_hat_zeit_mit_zone(self):
        ohne = [n for n in STEPS if beleg(n) is None or zeit(beleg(n)) is None]
        self.assertEqual(ohne, [], f"keine Zeile 'Zeit:' mit Zone in AC {ohne}")


class Reihenfolge(unittest.TestCase):
    def test_zeitstempel_halten_die_reihenfolge(self):
        stufen = []
        for gruppe in ORDER:
            zeiten = [zeit(beleg(n)) if beleg(n) else None for n in gruppe]
            self.assertNotIn(None, zeiten, f"Zeit fehlt in AC {gruppe}")
            stufen.append((gruppe, min(zeiten), max(zeiten)))
        for (g1, _, ende), (g2, anfang, _) in zip(stufen, stufen[1:]):
            self.assertLessEqual(ende, anfang, f"AC {g1} liegt nicht vor AC {g2}")


class Schreibwege(unittest.TestCase):
    def test_schreibende_laeufe_lesen_vorher_und_gegenprobe(self):
        fehler = []
        for n in sorted(WRITING):
            path = beleg(n)
            if path is None:
                fehler.append(f"AC-{n}: kein Beleg")
                continue
            text = path.read_text(encoding="utf-8").lower()
            if "lesen vorher" not in text:
                fehler.append(f"AC-{n}: 'lesen vorher' fehlt")
            if "gegenprobe" not in text:
                fehler.append(f"AC-{n}: 'Gegenprobe' fehlt")
        self.assertEqual(fehler, [])

    def test_kein_delete_und_kein_doppelter_post(self):
        fehler = []
        for path in sorted(HERE.glob("*")):
            if path.suffix not in {".md", ".txt", ".log"}:
                continue
            lines = path.read_text(encoding="utf-8").splitlines()
            if any(re.search(r"\bDELETE\s+/", l) for l in lines):
                fehler.append(f"{path.name}: DELETE")
            posts = [l.strip() for l in lines if re.search(r"\bPOST\s+/", l)]
            doppelt = sorted({p for p in posts if posts.count(p) > 1})
            if doppelt:
                fehler.append(f"{path.name}: doppelter POST {doppelt}")
        self.assertEqual(fehler, [])

    def test_keine_geheimnisse(self):
        fehler = []
        for path in sorted(HERE.glob("*")):
            if path.suffix not in {".md", ".txt", ".log"}:
                continue
            text = path.read_text(encoding="utf-8")
            for name, pattern in SECRET_PATTERNS.items():
                if pattern.search(text):
                    fehler.append(f"{path.name}: {name}")
        self.assertEqual(fehler, [])


class Einreichung(unittest.TestCase):
    def test_genau_ein_zustand(self):
        path = beleg(10)
        self.assertIsNotNone(path, "Beleg AC-10 fehlt")
        text = path.read_text(encoding="utf-8")
        zustaende = re.findall(r"^Zustand:\s*([ab])\s*$", text, re.M)
        self.assertEqual(len(zustaende), 1, "genau eine Zeile 'Zustand: a|b' erwartet")
        if zustaende[0] == "a":
            self.assertIn("WAITING_FOR_REVIEW", text)
            self.assertRegex(text, r"(?m)^Wort:\s*\S+", "Hennings Wort fehlt")
        else:
            self.assertIn("bereit", text)


class Betriebsnotiz(unittest.TestCase):
    def section(self):
        text = TESTFLIGHT_DOC.read_text(encoding="utf-8")
        m = re.search(r"^## Einreichung 1\.0\.2.*?(?=^## |\Z)", text, re.M | re.S)
        self.assertIsNotNone(m, "Abschnitt '## Einreichung 1.0.2' fehlt in testflight.md")
        return m.group(0)

    def test_acht_schritte(self):
        schritte = re.findall(r"^\d+\.\s", self.section(), re.M)
        self.assertEqual(len(schritte), 8)

    def test_pflichtsaetze(self):
        s = self.section()
        for wort in ["Etikett", "Tür", "öffentlich", "Aufnahme", "iPhone", "feat-625-s5d2-store-betrieb"]:
            self.assertIn(wort, s)


class Diffliste(unittest.TestCase):
    def test_kein_app_code_keine_werkzeuge(self):
        out = subprocess.run(
            ["git", "diff", "--name-only", "origin/main...HEAD"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.split()
        verboten = [f for f in out if any(p.search(f) for p in FORBIDDEN_DIFF)]
        self.assertEqual(verboten, [])


if __name__ == "__main__":
    unittest.main()
