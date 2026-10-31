"""Schreibt „Was testen“ (What to Test) an den TestFlight-Build mit der Lauf-Nummer (#347).

Aufruf: asc_what_to_test.py <build-nummer>
Umgebung: WHAT_TO_TEST (der Text, höchstens 4000 Zeichen) und dieselben Variablen wie
asc_wait_build.py. Läuft nach asc_wait_build.py, der Build ist also schon gelistet.
Der Text darf je Sprache einen Abschnitt haben: Zeilen, die mit `de:` oder `en:` beginnen (Code aus `LanguagePacks.shipped`),
eröffnen einen. Text ohne Marker ist Deutsch; eine Fassung ohne eigenen Abschnitt bekommt den deutschen Text.
Jede vorhandene Sprachfassung des Builds bekommt ihren Text; fehlt die Fassung einer ausgelieferten Sprache, wird sie angelegt.
Nur Standardbibliothek plus `openssl`. Schlüssel, Token und Signatur werden nie ausgegeben.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from asc_locales import GERMAN, asc_locales, language_locales
from asc_wait_build import Fatal, find_app_id, get_json, make_token, platform_filter, read_config
from shipped_languages import ROOT

LOCALE = GERMAN
MAX_LENGTH = 4000
ATTEMPTS = 5


def send_json(config, method, path, payload):
    """PATCH/POST gegen die ASC-API. 5xx, 408, 429 und Netzfehler werden wiederholt, andere 4xx sind Fatal."""
    for attempt in range(1, ATTEMPTS + 1):
        token = make_token(config["key_id"], config["issuer"], config["key_file"])
        request = urllib.request.Request(
            config["base"] + path, data=json.dumps(payload).encode(), method=method,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=30):
                return
        except urllib.error.HTTPError as error:
            if not (error.code >= 500 or error.code in (408, 429)):
                raise Fatal(f"ASC answered HTTP {error.code} for {method} {path}")
            print(f"ASC answered HTTP {error.code} for {method} {path}, retrying", flush=True)
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            print(f"No answer from ASC for {method} {path} ({type(error).__name__}), retrying", flush=True)
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"App Store Connect did not accept {method} {path}")


def get_data(config, path):
    """Liste `data` einer GET-Antwort; wiederholt, solange ASC nicht antwortet."""
    for attempt in range(1, ATTEMPTS + 1):
        body = get_json(config, path)
        if body is not None and isinstance(body.get("data"), list):
            return body["data"]
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"App Store Connect did not answer {path.split('?')[0]}")


def find_build_id(config, app_id, number):
    path = f"/v1/builds?filter[app]={app_id}&filter[version]={urllib.parse.quote(number, safe='')}{platform_filter(config)}"
    for record in get_data(config, path):
        if isinstance(record, dict) and (record.get("attributes") or {}).get("version") == number:
            return record["id"]
    raise Fatal(f"Build {number} is not listed in App Store Connect")


def split_sections(text, root=ROOT):
    """{Locale: Text} aus `de: …` / `en: …`-Abschnitten; Text ohne Marker ist Deutsch."""
    by_code = dict(language_locales(root))
    sections, current, prefix = {}, None, []
    for line in text.splitlines():
        code, _, rest = line.partition(":")
        if code in by_code:
            current = by_code[code]
            sections[current] = [rest.lstrip()]
        elif current is None:
            prefix.append(line)
        else:
            sections[current].append(line)
    joined = {locale: "\n".join(lines).strip() for locale, lines in sections.items()}
    lead = "\n".join(prefix).strip()
    if lead:
        if GERMAN in joined:
            raise Fatal("WHAT_TO_TEST has text before the first language marker and a de: section as well")
        joined[GERMAN] = lead
    joined = {locale: part for locale, part in joined.items() if part}
    if GERMAN not in joined:
        raise Fatal("WHAT_TO_TEST has no German text (every other language falls back to it)")
    return joined


def write_what_to_test(config, build_id, sections, root=ROOT):
    """Setzt whatsNew je Sprachfassung (Abschnitt der Sprache, sonst der deutsche) und legt die Fassungen
    der ausgelieferten Sprachen an, die fehlen. Gibt die Sprachen zurück."""
    def text_for(locale):
        return sections.get(locale) or sections[GERMAN]

    locales = []
    for record in get_data(config, f"/v1/builds/{build_id}/betaBuildLocalizations"):
        locale = (record.get("attributes") or {}).get("locale", "?")
        send_json(config, "PATCH", f"/v1/betaBuildLocalizations/{record['id']}", {"data": {
            "type": "betaBuildLocalizations", "id": record["id"], "attributes": {"whatsNew": text_for(locale)}}})
        locales.append(locale)
    for locale in asc_locales(root):
        if locale not in locales:
            send_json(config, "POST", "/v1/betaBuildLocalizations", {"data": {
                "type": "betaBuildLocalizations",
                "attributes": {"locale": locale, "whatsNew": text_for(locale)},
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
            locales.append(locale)
    return locales


def main(argv):
    if len(argv) != 2 or not argv[1].strip():
        print("usage: asc_what_to_test.py <build-number>", file=sys.stderr)
        return 2
    number = argv[1].strip()
    text = os.environ.get("WHAT_TO_TEST", "").strip()
    try:
        if not text:
            raise Fatal("WHAT_TO_TEST is empty: every TestFlight build says what to test (#347)")
        sections = split_sections(text)
        for locale, part in sections.items():
            if len(part) > MAX_LENGTH:
                raise Fatal(f"WHAT_TO_TEST ({locale}) has {len(part)} characters, TestFlight takes at most {MAX_LENGTH}")
        config = read_config()
        locales = write_what_to_test(config, find_build_id(config, find_app_id(config), number), sections)
        print(f"build={number} whatToTest gesetzt für {', '.join(locales)}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
