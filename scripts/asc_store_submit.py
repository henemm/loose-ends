"""Vorprüfung vor dem Einreichen der App-Store-Versionen zur Prüfung bei Apple (#893 Schnitt A).

Aufruf: asc_store_submit.py pruefen
Umgebung wie asc_version_texts.py. `pruefen` liest nur (GET) und wertet beide Plattformen vollständig aus: genau eine
bearbeitbare Version (PREPARE_FOR_SUBMISSION) mit gleicher Nummer auf beiden Plattformen, Bau zugeordnet, gültig, nicht
abgelaufen und zur Version passend, Texte de-DE und en-US, Bilder je Locale, Review-Detail und die Einreichungen der
Plattform. Je Plattform `<Plattform> bereit` oder je Grund `<Plattform> nicht-bereit: <Grund>`; Ausgang 0 nur, wenn
beide bereit sind. Ausgegeben werden nur Zustandswörter und Zeichenzahlen: nie Schlüssel, Token, Kennungen, Apples
Rohantwort oder Store-Wortlaut. Schnitt A schreibt nichts und reicht nichts ein; Schnitt B ergänzt `ACTIONS`.
"""
import re
import sys
import urllib.parse

from asc_beta_invite import Masked, message
from asc_beta_probe import attributes, records
from asc_store_version import count, current_build, get_one
from asc_version_texts import EDITABLE, PLATFORMS, app_versions, localizations
from asc_wait_build import Fatal, find_app_id, read_config
from asc_what_to_test import get_data

LOCALES = ("de-DE", "en-US")
REQUIRED = ("description", "keywords", "supportUrl", "whatsNew")
SIZES = ("description", "keywords", "supportUrl", "whatsNew", "promotionalText")
BUSY = ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING")
REUSABLE = "READY_FOR_REVIEW"
DONE = "COMPLETE"
SHORT = {"IOS": "ios", "MAC_OS": "mac"}


class Watched(Masked):
    """Masked-Ausgabe, die den Status der letzten Wiederholungszeile der geteilten Helfer merkt: nach 5xx nennt
    deren Fatal keinen Status mehr, der Grund `nicht lesbar HTTP <status>` braucht ihn trotzdem."""
    last = None

    def write(self, text):
        found = re.search(r"ASC answered HTTP (\d+)", text)
        if found:
            Watched.last = found.group(1)
        return super().write(text)


def unreadable(error):
    """Grund aus einem Lesefehler: nur der HTTP-Status, nie Apples Rohantwort."""
    found = re.search(r"HTTP (\d+)", str(error))
    status = found.group(1) if found else Watched.last
    return f"nicht lesbar HTTP {status}" if status else "nicht lesbar"


def guarded(reasons, label, read, *args):
    """Führt eine Lese-Teilprüfung aus; ein Fatal wird zum Grund `<label> nicht lesbar …`, Ergebnis dann None."""
    Watched.last = None
    try:
        return read(*args)
    except Fatal as error:
        reasons.append(f"{label} {unreadable(error)}")
        return None


def editable_for(versions, platform):
    """(bearbeitbare Versionen der Plattform, Zustände aller ihrer Versionen); gibt nichts aus."""
    mine = [item for item in versions if attributes(item).get("platform") == platform]
    found = [item for item in mine if attributes(item).get("appStoreState") == EDITABLE]
    return found, [attributes(item).get("appStoreState") or "?" for item in mine]


def check_build(config, platform, version, reasons):
    """Bau zugeordnet, VALID, nicht abgelaufen, Vorabversion gleich der Versionsnummer; jede Abweichung ein Grund."""
    result = guarded(reasons, "bau", current_build, config, version["id"])
    if result is None:
        return
    found, pre = result
    if found is None:
        reasons.append("kein Bau")
        print(f"bau {platform} kein Bau", flush=True)
        return
    values, target = attributes(found), attributes(version).get("versionString") or "?"
    state = values.get("processingState") or "?"
    print(f"bau {platform} {pre} ({values.get('version') or '?'}) processingState={state}", flush=True)
    if state != "VALID":
        reasons.append(f"bau processingState {state}")
    if values.get("expired") is True:
        reasons.append("bau abgelaufen")
    if pre != target:
        reasons.append(f"bau vorabversion Soll {target} Ist {pre}")


def check_texts(platform, found, reasons):
    """de-DE und en-US vorhanden, Pflichtfelder nicht leer; ausgegeben werden nur Zeichenzahlen."""
    for locale in LOCALES:
        if locale not in found:
            reasons.append(f"{locale} fehlt")
            continue
        values = attributes(found[locale])
        sizes = " ".join(f"{field} zeichen={len(values.get(field) or '')}" for field in SIZES)
        print(f"  {platform} {locale} {sizes}", flush=True)
        for field in REQUIRED:
            if not (values.get(field) or "").strip():
                reasons.append(f"{locale} {field} leer")


def screenshots(config, loc_id):
    """Summe der Bilder in den Bildsätzen einer Locale; eine gescheiterte Zählung → Fatal mit ihrer Anzeige."""
    sets = records({"data": get_data(config, f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")})
    shots = [count(config, f"/v1/appScreenshotSets/{item['id']}/appScreenshots") for item in sets]
    errors = [value for value in shots if isinstance(value, str)]
    if errors:
        raise Fatal(errors[0])
    return sum(shots)


def check_images(config, platform, found, reasons):
    """Je Locale mindestens ein Bild: Bildsätze oder Bibliotheksplatzierungen; nichts lesbar → `nicht lesbar`."""
    for locale in LOCALES:
        if locale not in found:
            continue
        problems = []
        shots = guarded(problems, "bilder", screenshots, config, found[locale]["id"])
        Watched.last = None
        placed = count(config, f"/v1/appStoreVersionLocalizations/{found[locale]['id']}/placements")
        if isinstance(placed, str):
            problems.append(f"bilder {unreadable(placed)}")
            placed = None
        print(f"  {platform} {locale} bilder={'?' if shots is None else shots} "
              f"platzierungen={'?' if placed is None else placed}", flush=True)
        if (shots or 0) + (placed or 0) > 0:
            continue
        reasons.append(f"{locale} {problems[0]}" if problems else f"{locale} keine Bilder")


def submissions(config, app_id, platform):
    query = urllib.parse.urlencode({"filter[app]": app_id, "filter[platform]": platform, "limit": "50"})
    return records({"data": get_data(config, f"/v1/reviewSubmissions?{query}")})


def check_submissions(config, app_id, platform, reasons, notes):
    """Einreichungen der Plattform: COMPLETE ignoriert, genau eine READY_FOR_REVIEW wiederverwendbar, sonst belegt."""
    rows = guarded(reasons, "einreichungen", submissions, config, app_id, platform)
    if rows is None:
        return
    states = [attributes(row).get("state") for row in rows if attributes(row).get("platform") in (None, platform)]
    print(f"einreichungen {platform} {', '.join(state or '?' for state in states) or 'keine'}", flush=True)
    ready = [state for state in states if state == REUSABLE]
    if len(ready) == 1:
        notes.append(f"einreichung {REUSABLE} wiederverwendbar")
    elif ready:
        reasons.append(f"einreichung {REUSABLE} {len(ready)}x, mehrdeutig")
    for state in states:
        if state in BUSY:
            reasons.append(f"belegt, einreichung {state}")
        elif state not in (DONE, REUSABLE):
            reasons.append(f"belegt, unbekannter Zustand {state or 'fehlt'}")


def check_version(config, platform, version, reasons):
    """Bau, Texte, Bilder und Review-Detail der einen bearbeitbaren Version."""
    print(f"version {platform} {attributes(version).get('versionString') or '?'} state={EDITABLE}", flush=True)
    check_build(config, platform, version, reasons)
    found = guarded(reasons, "texte", localizations, config, version["id"])
    if found is not None:
        check_texts(platform, found, reasons)
        check_images(config, platform, found, reasons)
    review = guarded(reasons, "review-detail", get_one, config,
                     f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail", True)
    unread = any(reason.startswith("review-detail") for reason in reasons)
    print(f"review-detail {platform} {'?' if unread else 'vorhanden' if review else 'keines'}", flush=True)
    if review is None and not unread:
        reasons.append("kein review-detail")


def check_platform(config, app_id, platform, versions, reasons, notes):
    """Alle Prüfungen einer Plattform; Gründe und Hinweise landen in den übergebenen Listen."""
    found, states = editable_for(versions, platform)
    if len(found) != 1:
        reasons.append(f"bearbeitbare Versionen={len(found)} (Zustände {', '.join(states) or 'keine'})")
    else:
        check_version(config, platform, found[0], reasons)
    check_submissions(config, app_id, platform, reasons, notes)


def same_number(versions, reasons):
    """Plattformübergreifend: die bearbeitbaren Versionen tragen dieselbe Nummer; sonst Grund bei beiden."""
    numbers = {}
    for platform in PLATFORMS:
        found = editable_for(versions, platform)[0]
        if len(found) == 1:
            numbers[platform] = attributes(found[0]).get("versionString") or "?"
    if len(numbers) == len(PLATFORMS) and len(set(numbers.values())) > 1:
        line = " ".join(f"{platform} {number}" for platform, number in numbers.items())
        for platform in PLATFORMS:
            reasons[platform].append(f"versionsnummern ungleich: {line}")


def pruefen(config, app_id):
    """Vorprüfung beider Plattformen, nur GET; Ausgang 0 nur, wenn beide bereit sind."""
    reasons = {platform: [] for platform in PLATFORMS}
    notes = {platform: [] for platform in PLATFORMS}
    versions = app_versions(config, app_id)
    for platform in PLATFORMS:
        check_platform(config, app_id, platform, versions, reasons[platform], notes[platform])
    same_number(versions, reasons)
    for platform in PLATFORMS:
        for note in notes[platform]:
            print(f"{platform} hinweis: {note}", flush=True)
        for reason in reasons[platform]:
            print(f"{platform} nicht-bereit: {reason}", flush=True)
        if not reasons[platform]:
            print(f"{platform} bereit", flush=True)
    ready = ",".join(SHORT[p] for p in PLATFORMS if not reasons[p]) or "keine"
    blocked = ",".join(SHORT[p] for p in PLATFORMS if reasons[p]) or "keine"
    print(f"zusammenfassung bereit={ready} nicht-bereit={blocked}", flush=True)
    if blocked != "keine":
        print(f"::error::nicht bereit: {blocked}", flush=True)
        return 1
    return 0


ACTIONS = {"pruefen": pruefen}


def main(argv):
    if len(argv) != 2 or argv[1] not in ACTIONS:
        print(f"::error::Aufruf: asc_store_submit.py {'|'.join(ACTIONS)}", flush=True)
        return 1
    try:
        config = read_config()
        app_id = find_app_id(config)
    except Fatal as error:
        print(f"::error::{message(error)}", flush=True)
        return 1
    try:
        return ACTIONS[argv[1]](config, app_id)
    except Fatal as error:
        print(f"::error::{message(error)}", flush=True)
        return 1


if __name__ == "__main__":
    sys.stdout = Watched(sys.stdout)
    sys.exit(main(sys.argv))
