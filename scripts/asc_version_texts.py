"""Liest und setzt die Texte der App-Store-Version in App Store Connect (#842 Schnitt 3, 5a-2).

Aufruf: asc_version_texts.py lesen|texte
Umgebung wie asc_wait_build.py plus VERSION_TEXTS_FILE (Standard docs/reference/app-store-texte.md, je Locale ein
Abschnitt `## <Locale>` mit `Beschreibung:` im Markerblock und den Zeilen `Schlüsselwörter:`, `Support-URL:`, optional
`Werbetext:` und `Neu in dieser Version:`). Ein Abschnitt ohne `Beschreibung:` trägt nur Werbetext und/oder Neu in
dieser Version und gilt nur für eine Sprache, die es bei Apple schon gibt (5a-2). `lesen` schreibt nichts und zeigt
auch den Werbetext der veröffentlichten Version (READY_FOR_SALE); `texte` schreibt je Plattform nur in die eine Version im Zustand
PREPARE_FOR_SUBMISSION, nur Locales aus der Datei, nur bei Abweichung, und prüft danach gegen. Es wird nichts
eingereicht. Die Store-Texte sind öffentlich und dürfen in der Ausgabe stehen; Schlüssel, Token und Rohantworten nie.
"""
import os
import sys
from pathlib import Path

from asc_beta_probe import attributes, records
from asc_wait_build import Fatal, find_app_id, read_config
from asc_what_to_test import get_data, send_json

ACTIONS = ("lesen", "texte")
EDITABLE = "PREPARE_FOR_SUBMISSION"
PLATFORMS = ("IOS", "MAC_OS")
FENCE = "```"
PUBLISHED = "READY_FOR_SALE"
LINE_FIELDS = {"Schlüsselwörter": "keywords", "Support-URL": "supportUrl", "Werbetext": "promotionalText",
               "Neu in dieser Version": "whatsNew"}
LABELS = {"description": "Beschreibung", "keywords": "Schlüsselwörter", "supportUrl": "Support-URL",
          "promotionalText": "Werbetext", "whatsNew": "Neu in dieser Version"}
REQUIRED = ("description", "keywords", "supportUrl")
OPTIONAL = ("promotionalText", "whatsNew")
PLACEHOLDER = "PLATZHALTER"
DEFAULT_FILE = Path(__file__).resolve().parent.parent / "docs" / "reference" / "app-store-texte.md"


def description_block(lines, start, locale):
    """Text zwischen den Markern ab Zeile `start`; Randleerzeilen werden abgeschnitten. Gibt (Text, nächste Zeile)."""
    if start >= len(lines) or lines[start].strip() != FENCE:
        raise Fatal(f"{locale} Beschreibung: unter der Zeile Beschreibung: fehlt der öffnende Marker {FENCE}")
    for end in range(start + 1, len(lines)):
        if lines[end].strip() == FENCE:
            block = lines[start + 1:end]
            while block and not block[0].strip():
                block.pop(0)
            while block and not block[-1].strip():
                block.pop()
            return "\n".join(block), end + 1
    raise Fatal(f"{locale} Beschreibung: der schließende Marker {FENCE} fehlt")


def parse_sections(text):
    """{Locale: {Feld: Wert}} aus der Textdatei; Text außerhalb der Abschnitte und fremde Zeilen werden ignoriert."""
    lines, sections, current, locale, index = text.splitlines(), {}, None, None, 0
    while index < len(lines):
        line = lines[index]
        index += 1
        if line.startswith("## "):
            locale = line[3:].strip()
            current = sections.setdefault(locale, {})
            continue
        if current is None:
            continue
        key, _, value = line.partition(":")
        if key.strip() == "Beschreibung" and not value.strip():
            current["description"], index = description_block(lines, index, locale)
        elif key.strip() in LINE_FIELDS and value.strip():
            current[LINE_FIELDS[key.strip()]] = value.strip()
    return sections


def check_required(locale, values):
    """Mit Beschreibung alle drei Pflichtfelder; ohne nur Werbetext/Neu-Text, mindestens eines davon (5a-2)."""
    if "description" in values:
        for field in REQUIRED:
            if not values.get(field, "").strip():
                raise Fatal(f"{locale} {LABELS[field]} fehlt oder ist leer")
        return
    if "keywords" in values or "supportUrl" in values:
        raise Fatal(f"{locale}: Schlüsselwörter/Support-URL ohne Beschreibung")
    if not any(values.get(field, "").strip() for field in OPTIONAL):
        raise Fatal(f"{locale}: Abschnitt ohne Beschreibung braucht Werbetext oder Neu in dieser Version")


def check_section(locale, values):
    """Pflichtfelder und Grenzen; Verstoß nennt Locale, Feld, Ist- und Soll-Zahl."""
    check_required(locale, values)
    limits = (("description", len(values.get("description", "")), 4000, "Zeichen"),
              ("promotionalText", len(values.get("promotionalText", "")), 170, "Zeichen"),
              ("whatsNew", len(values.get("whatsNew", "")), 4000, "Zeichen"),
              ("keywords", len(values.get("keywords", "").encode("utf-8")), 100, "Bytes"))
    for field, count, limit, unit in limits:
        if count > limit:
            raise Fatal(f"{locale} {LABELS[field]} hat {count} {unit}, erlaubt höchstens {limit}")
    spaces = values.get("keywords", "").count(", ")
    if spaces:
        raise Fatal(f"{locale} Schlüsselwörter: {spaces} Leerzeichen nach Komma, erlaubt 0")
    if "supportUrl" in values and not values["supportUrl"].startswith("https://"):
        raise Fatal(f"{locale} Support-URL muss mit https:// beginnen")


def wanted_texts(text):
    """{Locale: {description?, keywords?, supportUrl?, promotionalText?, whatsNew?}}; geprüft vor jeder Anfrage."""
    sections = parse_sections(text)
    if not sections:
        raise Fatal("Die Textdatei hat keinen Abschnitt ## <Locale>")
    for locale, values in sections.items():
        check_section(locale, values)
    return sections


def read_wanted():
    path = Path(os.environ.get("VERSION_TEXTS_FILE") or DEFAULT_FILE)
    try:
        return wanted_texts(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as error:
        raise Fatal(f"Die Textdatei ist nicht lesbar ({type(error).__name__})")


def app_versions(config, app_id):
    return records({"data": get_data(config, f"/v1/apps/{app_id}/appStoreVersions?limit=50")})


def localizations(config, version_id):
    """{Locale: Datensatz} der Lokalisierungen einer Version."""
    path = f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50"
    return {attributes(item).get("locale"): item for item in records({"data": get_data(config, path)})}


def editable_version(versions, platform):
    """Die eine Version der Plattform im Zustand PREPARE_FOR_SUBMISSION; keine → None, mehrere → Fatal."""
    mine = [item for item in versions if attributes(item).get("platform") == platform]
    states = [attributes(item).get("appStoreState") or "?" for item in mine]
    found = [item for item, state in zip(mine, states) if state == EDITABLE]
    if not found:
        print(f"keine bearbeitbare Version {platform} (Zustände {', '.join(states) or 'keine'}), nichts geschrieben",
              flush=True)
        return None
    if len(found) > 1:
        raise Fatal(f"{len(found)} Versionen {platform} im Zustand {EDITABLE}, mehrdeutig, nichts geschrieben")
    print(f"version {platform} {attributes(found[0]).get('versionString') or '?'} id={found[0]['id']} "
          f"state={EDITABLE}", flush=True)
    return found[0]


def read_state(config, versions):
    """Je Version Plattform und Zustand; für die bearbeitbare je Locale Zeichenzahl und Wortlaut der Felder."""
    for item in versions:
        values = attributes(item)
        print(f"version {values.get('platform') or '?'} {values.get('versionString') or '?'} "
              f"state={values.get('appStoreState') or '?'}", flush=True)
    for platform in PLATFORMS:
        chosen = editable_version(versions, platform)
        if chosen is None:
            continue
        for locale, record in localizations(config, chosen["id"]).items():
            for field, label in LABELS.items():
                value = attributes(record).get(field) or ""
                print(f"  {platform} {locale} {label} zeichen={len(value)}: {value or '-'}", flush=True)
    read_published(config, versions)
    return 0


def read_published(config, versions):
    """Werbetext der veröffentlichten Version je Plattform und Locale (5a-2); nur GET."""
    for item in versions:
        values = attributes(item)
        if values.get("appStoreState") != PUBLISHED:
            continue
        for locale, record in localizations(config, item["id"]).items():
            text = attributes(record).get("promotionalText") or ""
            print(f"veröffentlicht {values.get('platform') or '?'} {values.get('versionString') or '?'} {locale} "
                  f"Werbetext zeichen={len(text)}: {text or '-'}", flush=True)


def send(config, method, path, payload):
    """Schreibaufruf; 403 und 409 werden zu einer klaren Meldung ohne Apples Rohantwort."""
    try:
        send_json(config, method, path, payload)
    except Fatal as error:
        if "HTTP 403" in str(error):
            raise Fatal(f"Apple lehnt {method} ab (HTTP 403): Schlüssel ohne Recht oder Version gesperrt")
        if "HTTP 409" in str(error):
            _, codes, rest = str(error).partition(" (codes: ")
            raise Fatal(f"Apple meldet einen Konflikt (HTTP 409) für {method}: Wert oder Zustand nicht zulässig"
                        + (f" (codes: {rest}" if codes else ""))
        raise


def write_locale(config, version_id, locale, values, record):
    """Ein Schreibaufruf für eine Locale, falls nötig; gibt die geschriebenen Felder zurück (leer = unverändert)."""
    if record is None:
        send(config, "POST", "/v1/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **values},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        return dict(values)
    changed = {field: value for field, value in values.items() if attributes(record).get(field) != value}
    if changed:
        send(config, "PATCH", f"/v1/appStoreVersionLocalizations/{record['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": record["id"], "attributes": changed}})
    return changed


def check_no_placeholder(wanted):
    """Kein Wert darf das Wort PLATZHALTER tragen; geprüft im Pfad `texte` vor jeder Anfrage (5a-2, F002)."""
    for locale, values in wanted.items():
        for field, value in values.items():
            if PLACEHOLDER in value:
                raise Fatal(f"{locale} {LABELS[field]} enthält {PLACEHOLDER}, nichts geschrieben")


def check_locales_exist(config, chosen, wanted):
    """Lokalisierungen aller gewählten Versionen; ein Abschnitt ohne Beschreibung, dessen Sprache in irgendeiner
    davon fehlt, ist Fatal, bevor die erste Version geschrieben wird (AC-4, F001). Gibt {Versions-ID: Lokalisierungen}."""
    present = {item["id"]: localizations(config, item["id"]) for item in chosen}
    for item in chosen:
        for locale, values in wanted.items():
            if "description" not in values and locale not in present[item["id"]]:
                raise Fatal(f"{locale} fehlt bei Apple ({attributes(item).get('platform') or '?'}), Abschnitt "
                            "braucht Beschreibung, Schlüsselwörter, Support-URL")
    return present


def write_texts(config, version_id, wanted, present):
    """Schreibt die Locales aus der Datei in eine Version; gibt die Zahl der Schreibaufrufe zurück."""
    checks = {}
    for locale, values in wanted.items():
        written = write_locale(config, version_id, locale, values, present.get(locale))
        if not written:
            print(f"{locale} unverändert", flush=True)
            continue
        checks[locale] = written
        print(f"{locale} gesetzt: {', '.join(LABELS[field] for field in written)}", flush=True)
    if checks:
        verify(config, version_id, checks)
    return len(checks)


def verify(config, version_id, wanted):
    """Gegenprobe: liest die Lokalisierungen neu; jedes geschriebene Feld muss bei Apple exakt stehen."""
    present = localizations(config, version_id)
    for locale, values in wanted.items():
        found = attributes(present.get(locale))
        if any(found.get(field) != value for field, value in values.items()):
            raise Fatal(f"Gegenprobe: {locale} weicht vom Wunschtext ab")
    print("gegenprobe gleich=ja", flush=True)


def main(argv):
    try:
        if len(argv) != 2 or argv[1] not in ACTIONS:
            raise Fatal(f"Aufruf: asc_version_texts.py {'|'.join(ACTIONS)}")
        wanted = read_wanted() if argv[1] == "texte" else None
        if wanted is not None:
            check_no_placeholder(wanted)
        config = read_config()
        versions = app_versions(config, find_app_id(config))
        written = 0
        if wanted is None:
            written = read_state(config, versions)
        else:
            chosen = [item for item in (editable_version(versions, p) for p in PLATFORMS) if item is not None]
            present = check_locales_exist(config, chosen, wanted)
            for item in chosen:
                written += write_texts(config, item["id"], wanted, present[item["id"]])
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
