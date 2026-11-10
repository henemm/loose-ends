"""Liest den Stand der App-Store-Versionen und legt die Mac-Version samt Bau-Zuordnung an (#842 Schnitt 5a-1).

Aufruf: asc_store_version.py lesen|anlegen
Umgebung wie asc_wait_build.py. `lesen` schreibt nichts: je Version Zustand, für die bearbeitbare je Plattform Bau,
Zeichenzahlen je Feld (nie der Wortlaut), Bildsätze, Bilder, Platzierungen und ob ein Review-Detail existiert.
`anlegen` plant zuerst nur mit GET, legt dann höchstens die eine Mac-Version mit der Nummer der bearbeitbaren
iOS-Version an und ordnet je Plattform einen gültigen Bau zu, wo noch keiner hängt (höchste Buildnummer, nie
umgehängt), prüft im selben Lauf gegen und gibt den Stand wie `lesen` aus. Es wird nie eingereicht und nie gelöscht.
"""
import re
import sys
import time
import urllib.parse

from asc_beta_probe import attributes, records
from asc_version_texts import EDITABLE, PLATFORMS, app_versions, editable_version, localizations
from asc_wait_build import Fatal, find_app_id, get_json, read_config
from asc_what_to_test import ATTEMPTS, get_data, is_account_build, send_json

ACTIONS = ("lesen", "anlegen")
FIELDS = ("description", "keywords", "promotionalText", "whatsNew", "supportUrl")
BUILD_HINT = ": der Bau muss gültig, nicht abgelaufen und zu Plattform und Version passend sein"


def get_one(config, path, missing_ok_404=False):
    """Einzelobjekt `data` einer GET-Antwort; kein Datensatz (null, mit `missing_ok_404` auch 404) → None.
    Für Bau und Vorabversion heißt nur `data: null` „kein Bau“; ein 404 dort ist Fatal, damit nie umgehängt wird."""
    for attempt in range(1, ATTEMPTS + 1):
        try:
            body = get_json(config, path)
        except Fatal as error:
            if "HTTP 404" not in str(error):
                raise
            if missing_ok_404:
                return None
            raise Fatal(f"ASC antwortet HTTP 404 für {path.split('?')[0]}: Bau-Zuordnung unklar, nichts umgehängt")
        if body is not None:
            data = body.get("data")
            return data if isinstance(data, dict) and data.get("id") else None
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"App Store Connect did not answer {path.split('?')[0]}")


def current_build(config, version_id):
    """(Bau, Vorabversion) der Version; ohne Bau (None, None)."""
    found = get_one(config, f"/v1/appStoreVersions/{version_id}/build")
    if found is None:
        return None, None
    pre = get_one(config, f"/v1/builds/{found['id']}/preReleaseVersion")
    return found, attributes(pre).get("version") or "?"


def failed(error):
    """Anzeigewert einer gescheiterten Zähl-Abfrage: `fehler HTTP <status>`, ohne Apples Rohantwort."""
    status = re.search(r"HTTP \d+", str(error))
    return f"fehler {status.group()}" if status else "fehler"


def count(config, path):
    """Zahl der Einträge; eine gescheiterte reine Anzeige-Abfrage wird zu `fehler …`, der Lauf geht weiter."""
    try:
        return len(records({"data": get_data(config, path)}))
    except Fatal as error:
        return failed(error)


def report_version(config, platform, version_id):
    """Bau, Zeichenzahlen, Bildsätze und Platzierungen je Locale, Review-Detail einer bearbeitbaren Version."""
    found, pre = current_build(config, version_id)
    if found is None:
        print(f"bau {platform} kein Bau", flush=True)
    else:
        values = attributes(found)
        print(f"bau {platform} {pre} ({values.get('version') or '?'}) "
              f"processingState={values.get('processingState') or '?'}", flush=True)
    for locale, record in localizations(config, version_id).items():
        sizes = " ".join(f"{field} zeichen={len(attributes(record).get(field) or '')}" for field in FIELDS)
        try:
            sets = records({"data": get_data(config, f"/v1/appStoreVersionLocalizations/{record['id']}/appScreenshotSets")})
            shots = [count(config, f"/v1/appScreenshotSets/{item['id']}/appScreenshots") for item in sets]
            errors = [value for value in shots if isinstance(value, str)]
            shots = errors[0] if errors else sum(shots)
            sets = len(sets)
        except Fatal as error:
            sets = shots = failed(error)
        placed = count(config, f"/v1/appStoreVersionLocalizations/{record['id']}/placements")
        print(f"  {platform} {locale} {sizes}", flush=True)
        print(f"  {platform} {locale} bildsaetze={sets} bilder={shots} platzierungen={placed}", flush=True)
    review = get_one(config, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", missing_ok_404=True)
    print(f"review-detail {'vorhanden' if review else 'keines'}", flush=True)


def read_state(config, versions):
    """Ausgabe von `lesen`: nur GET."""
    for item in versions:
        values = attributes(item)
        print(f"version {values.get('platform') or '?'} {values.get('versionString') or '?'} "
              f"state={values.get('appStoreState') or '?'}", flush=True)
    for platform in PLATFORMS:
        chosen = editable_version(versions, platform)
        if chosen is not None:
            report_version(config, platform, chosen["id"])


def plan_mac_version(versions):
    """(Zielversion, bearbeitbare iOS-Version, bearbeitbare Mac-Version oder None); jede Abweichung → Fatal, bevor geschrieben wird."""
    ios = editable_version(versions, "IOS")
    if ios is None:
        raise Fatal("keine bearbeitbare Version IOS, keine Zielversion, nichts geschrieben")
    target = attributes(ios).get("versionString") or "?"
    mac = editable_version(versions, "MAC_OS")
    if mac is not None and attributes(mac).get("versionString") != target:
        raise Fatal(f"bearbeitbare Version MAC_OS {attributes(mac).get('versionString')} weicht von IOS {target} ab, "
                    "nichts geschrieben")
    return target, ios, mac


def pick_build(config, app_id, platform, target):
    """Gültiger, nicht abgelaufener, nicht gesperrter Bau der Zielversion mit der höchsten Buildnummer (numerisch);
    keiner → Fatal. Gesperrt ist ein Konto-Bau oder ein Bau mit unlesbaren Texten (`build_lock`)."""
    query = urllib.parse.urlencode({"filter[app]": app_id, "filter[preReleaseVersion.platform]": platform,
                                    "filter[preReleaseVersion.version]": target,
                                    "filter[processingState]": "VALID", "filter[expired]": "false", "limit": "50"})
    rows = [item for item in records({"data": get_data(config, f"/v1/builds?{query}")})
            if attributes(item).get("processingState") == "VALID" and attributes(item).get("expired") is not True
            and re.fullmatch(r"\d+(\.\d+)*", str(attributes(item).get("version")))]
    ordered = sorted(rows, key=lambda item: [int(part) for part in attributes(item)["version"].split(".")], reverse=True)
    skipped = 0
    for chosen in ordered:
        reason = build_lock(config, chosen["id"])
        if reason is None:
            print(f"bau {platform} gewählt: {attributes(chosen)['version']} von {len(rows)} gültigen", flush=True)
            return chosen
        print(f"bau {platform} {attributes(chosen)['version']} übersprungen: {reason}", flush=True)
        skipped += 1
    raise Fatal(f"kein gültiger Bau {target} für {platform}"
                + (f" ({skipped} übersprungen)" if skipped else "") + ", nichts geschrieben")


def build_lock(config, build_id):
    """Grund, einen Bau nie zuzuordnen (#615 S4c-2a), sonst None; fail-closed: Unlesbares sperrt.
    „konto“: ein Text „Was testen“ trägt die Marke; „texte nicht lesbar“: GET gescheitert, Liste leer, Text leer."""
    try:
        texts = [attributes(item).get("whatsNew")
                 for item in records({"data": get_data(config, f"/v1/builds/{build_id}/betaBuildLocalizations")})]
    except Fatal:
        return "texte nicht lesbar"
    if is_account_build(texts):
        return "konto"
    if not texts or any(not isinstance(text, str) or not text.strip() for text in texts):
        return "texte nicht lesbar"
    return None


def send(config, method, path, payload, hint=""):
    """Schreibaufruf; 403 und 409 werden zu einer klaren Meldung ohne Apples Rohantwort."""
    try:
        send_json(config, method, path, payload)
    except Fatal as error:
        if "HTTP 403" in str(error):
            raise Fatal(f"Apple lehnt {method} ab (HTTP 403): Schlüssel ohne Recht oder Version gesperrt")
        if "HTTP 409" in str(error):
            _, codes, rest = str(error).partition(" (codes: ")
            raise Fatal(f"Apple meldet einen Konflikt (HTTP 409) für {method}{hint or ': Zustand nicht zulässig'}"
                        + (f" (codes: {rest}" if codes else ""))
        raise


def assign_build(config, version_id, build_id):
    send(config, "PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
         {"data": {"type": "builds", "id": build_id}}, BUILD_HINT)


def the_mac_version(versions, target):
    mine = [item for item in versions if attributes(item).get("platform") == "MAC_OS"
            and attributes(item).get("appStoreState") == EDITABLE]
    if len(mine) != 1 or attributes(mine[0]).get("versionString") != target:
        found = ", ".join(attributes(item).get("versionString") or "?" for item in mine) or "keine"
        raise Fatal(f"Gegenprobe: MAC_OS Soll genau eine bearbeitbare Version {target}, Ist {found}")
    return mine[0]


def verify(config, app_id, target):
    """Gegenprobe: genau eine bearbeitbare Mac-Version, beide bearbeitbaren Versionen mit Bau der Zielversion."""
    versions = app_versions(config, app_id)
    the_mac_version(versions, target)
    wrong = []
    for platform in PLATFORMS:
        chosen = editable_version(versions, platform)
        pre = current_build(config, chosen["id"])[1] if chosen else None
        if pre != target:
            wrong.append(f"{platform} Soll Bau {target}, Ist {pre or 'kein Bau'}")
    if wrong:
        raise Fatal(f"Gegenprobe: {'; '.join(wrong)}")
    print("gegenprobe gleich=ja", flush=True)
    return versions


def anlegen(config, app_id):
    """Plan nur mit GET, dann Mac-Version und fehlende Bau-Zuordnungen; gibt die Zahl der Schreibaufrufe zurück."""
    target, ios, mac = plan_mac_version(app_versions(config, app_id))
    plan, chosen = {}, {"IOS": ios, "MAC_OS": mac}
    for platform in PLATFORMS:
        present = current_build(config, chosen[platform]["id"])[0] if chosen[platform] else None
        if present is not None:
            print(f"bau {platform} schon zugeordnet: {attributes(present).get('version') or '?'}, unverändert",
                  flush=True)
        else:
            plan[platform] = pick_build(config, app_id, platform, target)
    written = 0
    if mac is None:
        send(config, "POST", "/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions", "attributes": {"platform": "MAC_OS", "versionString": target},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        written += 1
        chosen["MAC_OS"] = the_mac_version(app_versions(config, app_id), target)
        print(f"version MAC_OS {target} angelegt", flush=True)
    else:
        print(f"version MAC_OS {target} schon vorhanden, übersprungen", flush=True)
    for platform, found in plan.items():
        assign_build(config, chosen[platform]["id"], found["id"])
        written += 1
        print(f"bau {platform} zugeordnet: {attributes(found).get('version')}", flush=True)
    read_state(config, verify(config, app_id, target))
    return written


def main(argv):
    try:
        if len(argv) != 2 or argv[1] not in ACTIONS:
            raise Fatal(f"Aufruf: asc_store_version.py {'|'.join(ACTIONS)}")
        config = read_config()
        app_id = find_app_id(config)
        written = 0
        if argv[1] == "lesen":
            read_state(config, app_versions(config, app_id))
        else:
            written = anlegen(config, app_id)
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
