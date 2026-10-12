"""Schreibt „Was testen“ (What to Test) an den TestFlight-Build mit der Lauf-Nummer (#347).

Aufruf: asc_what_to_test.py <build-nummer>
Umgebung: WHAT_TO_TEST (der Text, höchstens 4000 Zeichen) und dieselben Variablen wie
asc_wait_build.py. Läuft nach asc_wait_build.py, der Build ist also schon gelistet.
Jede vorhandene Sprachfassung des Builds bekommt den Text; fehlt de-DE, wird sie angelegt.
Nur Standardbibliothek plus `openssl`. Schlüssel, Token und Signatur werden nie ausgegeben.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from asc_wait_build import Fatal, find_app_id, get_json, make_token, read_config

LOCALE = "de-DE"
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
    path = f"/v1/builds?filter[app]={app_id}&filter[version]={urllib.parse.quote(number, safe='')}"
    for record in get_data(config, path):
        if isinstance(record, dict) and (record.get("attributes") or {}).get("version") == number:
            return record["id"]
    raise Fatal(f"Build {number} is not listed in App Store Connect")


def write_what_to_test(config, build_id, text):
    """Setzt whatsNew in jeder Sprachfassung und legt de-DE an, wenn sie fehlt. Gibt die Sprachen zurück."""
    locales = []
    for record in get_data(config, f"/v1/builds/{build_id}/betaBuildLocalizations"):
        send_json(config, "PATCH", f"/v1/betaBuildLocalizations/{record['id']}", {"data": {
            "type": "betaBuildLocalizations", "id": record["id"], "attributes": {"whatsNew": text}}})
        locales.append((record.get("attributes") or {}).get("locale", "?"))
    if LOCALE not in locales:
        send_json(config, "POST", "/v1/betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": LOCALE, "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
        locales.append(LOCALE)
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
        if len(text) > MAX_LENGTH:
            raise Fatal(f"WHAT_TO_TEST has {len(text)} characters, TestFlight takes at most {MAX_LENGTH}")
        config = read_config()
        locales = write_what_to_test(config, find_build_id(config, find_app_id(config), number), text)
        print(f"build={number} whatToTest gesetzt für {', '.join(locales)}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
