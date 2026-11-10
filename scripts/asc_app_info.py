"""Liest und setzt Name, Untertitel und Datenschutz-Adresse der App-Informationen in App Store Connect (#837, #893 D).

Aufruf: asc_app_info.py lesen|untertitel|datenschutz
Umgebung wie asc_wait_build.py plus APP_INFO_FILE (Standard docs/reference/app-store-untertitel.md, je Sprache ein
Abschnitt `## de-DE` mit Zeilen `Name:` und `Untertitel:`). `lesen` schreibt nichts; `untertitel` schreibt nur in die eine
App-Info im Zustand PREPARE_FOR_SUBMISSION, nur bei Abweichung, und prüft danach gegen. `datenschutz` setzt nur `privacyPolicyUrl`
je Sprache (de-DE aus ASC_PRIVACY_POLICY_URL, en-US aus ASC_PRIVACY_POLICY_URL_EN oder PRIVACY_URL_EN) unter denselben
Regeln und legt keine Lokalisierung an. Name, Untertitel und Adresse sind öffentlich und dürfen in der Ausgabe stehen;
Schlüssel, Token und Apples Rohantworten nie.
"""
import os
import sys
from pathlib import Path

from asc_beta_probe import attributes, records
from asc_beta_setup import PRIVACY_URL_EN
from asc_locales import GERMAN, asc_locales
from asc_wait_build import Fatal, find_app_id, read_config
from asc_what_to_test import get_data, send_json

ACTIONS = ("lesen", "untertitel", "datenschutz")
MAX_CHARS = 30
EDITABLE = "PREPARE_FOR_SUBMISSION"
FIELDS = {"Name": "name", "Untertitel": "subtitle"}
DEFAULT_FILE = Path(__file__).resolve().parent.parent / "docs" / "reference" / "app-store-untertitel.md"


def wanted_texts(text):
    """{Locale: {"name"?, "subtitle"}} je ausgelieferter Sprache; prüft Abschnitte und Grenze, bevor eine Anfrage läuft."""
    sections, current = {}, None
    for line in text.splitlines():
        if line.startswith("## "):
            current = sections.setdefault(line[3:].strip(), {})
            continue
        key, _, value = line.partition(":")
        if current is not None and key.strip() in FIELDS and value.strip():
            current[FIELDS[key.strip()]] = value.strip()
    wanted = {}
    for locale in asc_locales():
        values = sections.get(locale)
        if not values or "subtitle" not in values:
            raise Fatal(f"Die Untertitel-Datei hat keinen Abschnitt ## {locale} mit Zeile Untertitel:")
        for field, value in values.items():
            if len(value) > MAX_CHARS:
                raise Fatal(f"{locale} {field} hat {len(value)} Zeichen, Apple erlaubt höchstens {MAX_CHARS}")
        wanted[locale] = values
    return wanted


def read_wanted():
    path = Path(os.environ.get("APP_INFO_FILE") or DEFAULT_FILE)
    try:
        return wanted_texts(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as error:
        raise Fatal(f"Die Untertitel-Datei ist nicht lesbar ({type(error).__name__})")


def wanted_privacy():
    """{Locale: Adresse} je ausgelieferter Sprache; fehlt eine oder ist sie nicht https, Abbruch vor jeder Anfrage."""
    sources = {GERMAN: os.environ.get("ASC_PRIVACY_POLICY_URL", "").strip(),
               "en-US": os.environ.get("ASC_PRIVACY_POLICY_URL_EN", "").strip() or PRIVACY_URL_EN}
    wanted = {}
    for locale in asc_locales():
        address = sources.get(locale, "")
        if not address:
            raise Fatal(f"Datenschutz-Adresse für {locale} fehlt, nichts geschrieben")
        if not address.startswith("https://"):
            raise Fatal(f"Datenschutz-Adresse für {locale} beginnt nicht mit https://, nichts geschrieben")
        wanted[locale] = address
    return wanted


def app_infos(config, app_id):
    return records({"data": get_data(config, f"/v1/apps/{app_id}/appInfos")})


def localizations(config, info_id):
    """{Locale: Datensatz} der Lokalisierungen einer App-Info."""
    found = records({"data": get_data(config, f"/v1/appInfos/{info_id}/appInfoLocalizations")})
    return {attributes(item).get("locale"): item for item in found}


def editable_info(infos):
    """Die eine App-Info im Zustand PREPARE_FOR_SUBMISSION; nie die erste beste."""
    states = [attributes(item).get("state") or "?" for item in infos]
    found = [item for item, state in zip(infos, states) if state == EDITABLE]
    if not found:
        raise Fatal(f"App-Informationen gesperrt (Zustände {', '.join(states) or 'keine'}), nichts geschrieben")
    if len(found) > 1:
        raise Fatal(f"{len(found)} App-Infos im Zustand {EDITABLE}, mehrdeutig, nichts geschrieben")
    print(f"appinfo id={found[0]['id']} state={EDITABLE}", flush=True)
    return found[0]["id"]


def read_state(config, infos):
    """Je App-Info Zustand, je Sprache Name und Untertitel."""
    for item in infos:
        print(f"appinfo id={item.get('id')} state={attributes(item).get('state') or '?'}", flush=True)
        for locale, record in localizations(config, item.get("id")).items():
            values = attributes(record)
            print(f"  {locale} name={values.get('name') or '-'} untertitel={values.get('subtitle') or '-'}"
                  f" datenschutz={values.get('privacyPolicyUrl') or '-'}", flush=True)
    return 0


def send(config, method, path, payload):
    """Schreibaufruf; 403 und 409 werden zu einer klaren Meldung ohne Apples Rohantwort."""
    try:
        send_json(config, method, path, payload)
    except Fatal as error:
        if "HTTP 403" in str(error):
            raise Fatal(f"Apple lehnt {method} ab (HTTP 403): App-Informationen gesperrt oder Schlüssel ohne Recht")
        if "HTTP 409" in str(error):
            _, codes, rest = str(error).partition(" (codes: ")
            raise Fatal(f"Apple meldet einen Konflikt (HTTP 409) für {method}: Wert oder Zustand nicht zulässig"
                        + (f" (codes: {rest}" if codes else ""))
        raise


def write_subtitles(config, info_id, wanted):
    """PATCH bei abweichendem Untertitel, POST für eine fehlende Sprache; gibt die Zahl der Schreibaufrufe zurück."""
    present, written, checks = localizations(config, info_id), 0, {}
    for locale, values in wanted.items():
        record = present.get(locale)
        if record is not None and attributes(record).get("subtitle") == values["subtitle"]:
            print(f"{locale} untertitel unverändert", flush=True)
            continue
        if record is not None:
            send(config, "PATCH", f"/v1/appInfoLocalizations/{record['id']}", {"data": {
                "type": "appInfoLocalizations", "id": record["id"], "attributes": {"subtitle": values["subtitle"]}}})
        elif "name" not in values:
            raise Fatal(f"{locale} fehlt bei Apple, die Untertitel-Datei nennt aber keinen Namen zum Anlegen")
        else:
            send(config, "POST", "/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations",
                "attributes": {"locale": locale, "name": values["name"], "subtitle": values["subtitle"]},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}})
        written += 1
        checks[locale] = values if record is None else {"subtitle": values["subtitle"]}
        print(f"{locale} untertitel gesetzt: {values['subtitle']}", flush=True)
    if written:
        verify(config, info_id, checks)
    return written


def write_privacy(config, info_id, wanted):
    """PATCH nur `privacyPolicyUrl` bei Abweichung; eine fehlende Sprache wird nicht angelegt. Zahl der Schreibaufrufe."""
    present, written, checks = localizations(config, info_id), 0, {}
    missing = [locale for locale in wanted if locale not in present]
    if missing:
        raise Fatal(f"{', '.join(missing)} fehlt bei Apple, Anlegen ist Sache von untertitel, nichts geschrieben")
    for locale, address in wanted.items():
        record = present[locale]
        if attributes(record).get("privacyPolicyUrl") == address:
            print(f"{locale} datenschutz unverändert", flush=True)
            continue
        send(config, "PATCH", f"/v1/appInfoLocalizations/{record['id']}", {"data": {
            "type": "appInfoLocalizations", "id": record["id"], "attributes": {"privacyPolicyUrl": address}}})
        written += 1
        checks[locale] = {"privacyPolicyUrl": address}
        print(f"{locale} datenschutz gesetzt: {address}", flush=True)
    if written:
        verify(config, info_id, checks)
    return written


def verify(config, info_id, wanted):
    """Gegenprobe: liest die Lokalisierungen neu; jeder geschriebene Wert muss bei Apple stehen."""
    present = localizations(config, info_id)
    for locale, values in wanted.items():
        found = attributes(present.get(locale))
        if any(found.get(field) != value for field, value in values.items()):
            raise Fatal(f"Gegenprobe: {locale} bei Apple weicht vom Wunschtext ab")
    print("gegenprobe gleich=ja", flush=True)


def main(argv):
    try:
        if len(argv) != 2 or argv[1] not in ACTIONS:
            raise Fatal(f"Aufruf: asc_app_info.py {'|'.join(ACTIONS)}")
        action = argv[1]
        wanted = read_wanted() if action == "untertitel" else wanted_privacy() if action == "datenschutz" else None
        config = read_config()
        infos = app_infos(config, find_app_id(config))
        if action == "lesen":
            written = read_state(config, infos)
        elif action == "untertitel":
            written = write_subtitles(config, editable_info(infos), wanted)
        else:
            written = write_privacy(config, editable_info(infos), wanted)
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
