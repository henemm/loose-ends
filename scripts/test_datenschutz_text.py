"""Datenschutztext mit Konto-Teil (#615 Schnitt 4e): Kernaussagen da, veraltete Sätze weg.

Das Skript belegt nur, dass der Text die freigegebenen Kernsätze enthält und die veralteten nicht; ob die Aussagen
wahr sind, belegt die Beleg-Tabelle im Entwurf (Code und Betrieb). Die Live-Seiten auf henemm.com prüft es nur mit
DATENSCHUTZ_LIVE=1, sonst werden diese Tests übersprungen.
"""
import html
import os
import pathlib
import re
import unittest
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DRAFT = ROOT / "docs/reference/datenschutz-entwurf.md"
LIVE_URLS = {
    "de": "https://www.henemm.com/legal/loose-ends/privacy-policy/",
    "en": "https://www.henemm.com/legal/loose-ends/privacy-policy-en/",
}
SECTION_TITLE = {
    "de": "Wenn du die Verbindung zu Claude nutzt",
    "en": "If you use the connection to Claude",
}
CORE = {
    "de": [r"14 Tage", r"30 Tage", r"90 Tage", r"Hetzner", r"Deutschland", r"Konto löschen",
           r"Art\. 6 Abs\. 1 lit\. f"],
    "en": [r"14 days", r"30 days", r"90 days", r"Hetzner", r"Germany", r"Delete account", r"Art\. 6\(1\)\(f\)"],
}
# Wendungen des Textes vor dem Konto-Teil; „kein Konto bei uns“ ist erlaubt, der neue Abschnitt sagt es absichtlich.
STALE = ["keinen eigenen Server", "Kein eigenes Backend", "no server of our own", "No backend of our own"]
# Kernsätze der Punkte 1 bis 4, wörtlich aus der freigegebenen Spec.
ANCHORS = {
    "de": [
        "Nur wenn du die freiwillige Verbindung zu Claude nutzt",
        "Einen eigenen Dienst (Server) gibt es nur für die freiwillige Verbindung zu Claude",
        "Das ist freiwillig. Ohne sie gibt es kein Konto bei uns und keinen Datenverkehr zu unserem Dienst.",
        "Aufträge und Ergebnisse bleiben gespeichert, bis du dein Konto löschst.",
        "Der Dienst läuft auf einem Server der Hetzner Online GmbH in Deutschland.",
        "Die Protokolle werden nach 14 Tagen gelöscht.",
        "Sicherungen werden höchstens 30 Tage aufbewahrt.",
        "ein Konto bei unserem Dienst mit „Konto löschen“ in den Einstellungen der App.",
    ],
    "en": [
        "Only if you use the voluntary connection to Claude",
        "There is a service (server) of our own only for the voluntary connection to Claude",
        "This is voluntary. Without it there is no account with us and no traffic to our service.",
        "Orders and results stay stored until you delete your account.",
        "The service runs on a server of Hetzner Online GmbH in Germany.",
        "The logs are deleted after 14 days.",
        "Backups are kept for 30 days at most.",
        "an account with our service with \"Delete account\" in the app's settings.",
    ],
}
TRANSCRIPT = {"de": "Abschrift", "en": "transcript"}


def normalize(text: str) -> str:
    """Zeilenumbrüche und Blockzitat-Zeichen zu einfachen Leerzeichen, damit umbrochene Sätze vergleichbar bleiben."""
    text = re.sub(r"^\s*>\s?", "", text, flags=re.MULTILINE)
    return re.sub(r"\s+", " ", text)


def split_draft(text: str):
    """Deutscher Teil (vor „## English“) und englischer Teil (ab dort)."""
    head, sep, tail = text.partition("\n## English")
    if not sep:
        raise AssertionError("Abschnitt „## English“ fehlt im Entwurf")
    return {"de": head, "en": tail}


def section(text: str, lang: str) -> str:
    """Der Konto-Abschnitt einer Sprache bis zur nächsten Überschrift gleicher Ebene, leer wenn er fehlt."""
    level = "##" if lang == "de" else "###"
    match = re.search(rf"^{level} [^\n]*{re.escape(SECTION_TITLE[lang])}[^\n]*\n(.*?)(?=^{level} |\Z)",
                      text, flags=re.MULTILINE | re.DOTALL)
    return match.group(1) if match else ""


def missing_core(text: str, lang: str):
    flat = normalize(text)
    return [p for p in CORE[lang] if not re.search(p, flat)]


def missing_anchors(text: str, lang: str):
    flat = normalize(text)
    return [a for a in ANCHORS[lang] if a not in flat]


def stale_phrases(text: str):
    flat = normalize(text)
    return [s for s in STALE if s in flat]


def draft_text() -> str:
    if not DRAFT.exists():
        raise AssertionError(f"{DRAFT.relative_to(ROOT)} fehlt")
    return DRAFT.read_text(encoding="utf-8")


def page_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=20) as response:
        if response.status != 200:
            raise AssertionError(f"{url}: HTTP {response.status}")
        raw = response.read().decode("utf-8")
    raw = re.sub(r"<(script|style)\b.*?</\1>", " ", raw, flags=re.DOTALL | re.IGNORECASE)
    return html.unescape(re.sub(r"<[^>]+>", " ", raw))


class DraftTests(unittest.TestCase):
    def setUp(self):
        self.text = draft_text()
        self.parts = split_draft(self.text)

    def test_core_statements_per_language(self):
        for lang, part in self.parts.items():
            with self.subTest(lang=lang):
                self.assertEqual(missing_core(part, lang), [], f"Kernaussagen fehlen ({lang})")

    def test_released_sentences_per_language(self):
        for lang, part in self.parts.items():
            with self.subTest(lang=lang):
                self.assertEqual(missing_anchors(part, lang), [], f"freigegebene Sätze fehlen ({lang})")

    def test_no_stale_phrases(self):
        self.assertEqual(stale_phrases(self.text), [], "veraltete Sätze im Entwurf")

    def test_account_section_exists_in_order(self):
        de = self.parts["de"]
        self.assertTrue(section(de, "de"), "deutscher Konto-Abschnitt fehlt")
        where = de.find("## Wo es liegt")
        account = de.find(f"## {SECTION_TITLE['de']}")
        rights = de.find("## Welche Rechte und warum")
        self.assertTrue(0 <= where < account < rights, "Konto-Abschnitt steht nicht zwischen „Wo es liegt“ und „Welche Rechte“")
        self.assertIn(f"### 4. {SECTION_TITLE['en']}", self.parts["en"], "englischer Abschnitt 4 fehlt")
        self.assertIn("### 7. Your rights, deletion and changes", self.parts["en"], "englischer Abschnitt 7 fehlt")

    def test_no_transcript_in_account_section(self):
        for lang, part in self.parts.items():
            with self.subTest(lang=lang):
                body = section(part, lang)
                self.assertTrue(body, f"Konto-Abschnitt fehlt ({lang})")
                self.assertNotIn(TRANSCRIPT[lang].lower(), body.lower())


class CheckerTests(unittest.TestCase):
    """Gegenprobe: die Prüfung fängt veraltete Sätze und fehlende Zahlen auch wirklich."""

    def test_stale_sentence_is_caught(self):
        self.assertEqual(stale_phrases("Es gibt keinen eigenen Server, kein Konto bei uns."), ["keinen eigenen Server"])

    def test_wrapped_stale_sentence_is_caught(self):
        self.assertEqual(stale_phrases("> Kein eigenes\n> Backend, kein Tracking."), ["Kein eigenes Backend"])

    def test_account_without_us_is_allowed(self):
        self.assertEqual(stale_phrases("Ohne sie gibt es kein Konto bei uns."), [])

    def test_missing_number_is_caught(self):
        self.assertIn(r"14 Tage", missing_core("Die Protokolle werden nach 15 Tagen gelöscht.", "de"))

    def test_transcript_found_in_section(self):
        text = "## Wenn du die Verbindung zu Claude nutzt\nDie Abschrift geht hoch.\n## Welche Rechte und warum\n"
        self.assertIn("Abschrift", section(text, "de"))


@unittest.skipUnless(os.environ.get("DATENSCHUTZ_LIVE") == "1", "Live-Seiten nur mit DATENSCHUTZ_LIVE=1")
class LiveTests(unittest.TestCase):
    def test_live_pages(self):
        for lang, url in LIVE_URLS.items():
            with self.subTest(lang=lang):
                text = page_text(url)
                self.assertEqual(missing_core(text, lang), [], f"{url}: Kernaussagen fehlen")
                self.assertEqual(missing_anchors(text, lang), [], f"{url}: freigegebene Sätze fehlen")
                self.assertIn(SECTION_TITLE[lang], normalize(text), f"{url}: Konto-Abschnitt fehlt")
                self.assertEqual(stale_phrases(text), [], f"{url}: veraltete Sätze")
                for internal in ("Beleg im Code", "Offen, nicht belegt"):
                    self.assertNotIn(internal, text, f"{url}: interner Abschnitt öffentlich")


if __name__ == "__main__":
    unittest.main()
