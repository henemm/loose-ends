"""Liest und setzt die App-Review-Notizen der bearbeitbaren Version je Plattform in App Store Connect (#788 Schnitt 1,
#625 S5d-1: iOS und Mac, je die eine Version im Zustand PREPARE_FOR_SUBMISSION statt fest iOS 1.0).

Aufruf: asc_review_notes.py lesen|notizen
Umgebung wie asc_wait_build.py plus REVIEW_NOTES_FILE (Standard docs/reference/app-review-notizen.md; der Text ist der
erste Codeblock darin). `lesen` schreibt nichts; `notizen` liest zuerst Version und Review-Detail beider Plattformen,
schreibt `notes` je Plattform nur bei Abweichung (ein PATCH, nie wiederholt) und prüft danach gegen. Es wird nichts
angelegt. Ausgegeben werden nur Zustände und Bytezahlen, nie der Notes-Text oder Kontaktfelder (das Repo ist öffentlich).
"""
import os
import sys
import time
from pathlib import Path

from asc_beta_probe import attributes, records
from asc_store_version import send_once
from asc_version_texts import PLATFORMS, app_versions, editable_version
from asc_wait_build import Fatal, find_app_id, get_json, read_config
from asc_what_to_test import ATTEMPTS, get_data

ACTIONS = ("lesen", "notizen")
MAX_BYTES = 4000
PLACEHOLDER = "<HIER_"
FENCE = "```"
DEFAULT_FILE = Path(__file__).resolve().parent.parent / "docs" / "reference" / "app-review-notizen.md"


def extract_notes(text):
    """Inhalt des ersten Codeblocks, führende und abschließende Leerzeilen entfernt, sonst unverändert."""
    lines = text.splitlines()
    fences = [index for index, line in enumerate(lines) if line.rstrip() == FENCE]
    if len(fences) < 2:
        raise Fatal("Die Notizdatei hat keinen Codeblock")
    body = lines[fences[0] + 1:fences[1]]
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    if not body:
        raise Fatal("Der Codeblock der Notizdatei ist leer")
    return "\n".join(body)


def wanted_notes():
    """Wunschtext aus der Datei; prüft Bytegrenze und Platzhalter, bevor eine Anfrage läuft."""
    path = Path(os.environ.get("REVIEW_NOTES_FILE") or DEFAULT_FILE)
    try:
        text = extract_notes(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError) as error:
        raise Fatal(f"Die Notizdatei ist nicht lesbar ({type(error).__name__})")
    size = len(text.encode("utf-8"))
    if size > MAX_BYTES:
        raise Fatal(f"Die Notizen haben {size} Byte, Apple erlaubt höchstens {MAX_BYTES}")
    if PLACEHOLDER in text:
        raise Fatal(f"Die Notizen enthalten noch einen Platzhalter {PLACEHOLDER}…")
    return text


def editable_versions(config, app_id, required):
    """[(Plattform, Version)] je Plattform die eine bearbeitbare Version (#625 S5d-1); mehrere → Fatal, keine → mit
    `required` Fatal, sonst übersprungen."""
    versions = app_versions(config, app_id)
    chosen = []
    for platform in PLATFORMS:
        found = editable_version(versions, platform)
        if found is None and required:
            raise Fatal(f"keine bearbeitbare Version {platform}, nichts geschrieben")
        if found is not None:
            chosen.append((platform, found))
    return chosen


def get_detail(config, platform, version):
    """Das Review-Detail der Version; fehlt es (404 oder null), Abbruch ohne Anlegen."""
    path = f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail"
    number = attributes(version).get("versionString") or "?"
    missing = Fatal(f"{platform} Version {number} hat keine App-Review-Informationen, nichts angelegt")
    for attempt in range(1, ATTEMPTS + 1):
        try:
            body = get_json(config, path)
        except Fatal as error:
            raise missing if "HTTP 404" in str(error) else error
        if body is not None:
            data = body.get("data")
            if not isinstance(data, dict) or not data.get("id"):
                raise missing
            return data
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"App Store Connect did not answer {path}")


def notes_of(detail):
    value = attributes(detail).get("notes")
    return value if isinstance(value, str) else ""


def notes_state(notes):
    return f"notizen gesetzt bytes={len(notes.encode('utf-8'))}" if notes else "notizen leer"


def read_state(config, platform, detail):
    """Zustand der Notizen und Anhänge, ohne Werte."""
    print(f"{platform} {notes_state(notes_of(detail))}", flush=True)
    attachments = records({"data": get_data(config, f"/v1/appStoreReviewDetails/{detail['id']}/appStoreReviewAttachments")})
    for item in attachments:
        values = attributes(item)
        delivery = values.get("assetDeliveryState")
        state = delivery.get("state") if isinstance(delivery, dict) else None
        print(f"{platform} anhang name={values.get('fileName') or '?'} groesse={values.get('fileSize', '?')} "
              f"assetDeliveryState={state or '?'}", flush=True)
    if not attachments:
        print(f"{platform} anhang keine", flush=True)
    return 0


def write_notes(config, platform, version, detail, wanted):
    """Schreibt `notes` nur bei Abweichung (ein PATCH, nie wiederholt), prüft danach gegen; gibt die Zahl der
    Schreibaufrufe zurück."""
    size = len(wanted.encode("utf-8"))
    if notes_of(detail) == wanted:
        print(f"{platform} notizen unverändert bytes={size}", flush=True)
        return 0
    payload = {"data": {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": wanted}}}
    try:
        send_once(config, "PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", payload)
    except Fatal as error:
        if "HTTP 403" in str(error) or "HTTP 409" in str(error):
            state = attributes(version).get("appStoreState") or "?"
            raise Fatal(f"{platform}: Apple lässt die Notizen im Zustand {state} nicht zu")
        raise Fatal(f"{platform}: {error}")
    print(f"{platform} notizen gesetzt bytes={size}", flush=True)
    if notes_of(get_detail(config, platform, version)) != wanted:
        raise Fatal(f"Gegenprobe: {platform} die Notizen bei Apple weichen vom Wunschtext ab")
    print(f"{platform} gegenprobe gleich=ja", flush=True)
    return 1


def main(argv):
    try:
        if len(argv) != 2 or argv[1] not in ACTIONS:
            raise Fatal(f"Aufruf: asc_review_notes.py {'|'.join(ACTIONS)}")
        wanted = wanted_notes() if argv[1] == "notizen" else None
        config = read_config()
        chosen = editable_versions(config, find_app_id(config), required=wanted is not None)
        # Plan beider Plattformen (nur GET) vor dem ersten Schreibaufruf
        plan = [(platform, version, get_detail(config, platform, version)) for platform, version in chosen]
        written = 0
        for platform, version, detail in plan:
            if wanted is None:
                read_state(config, platform, detail)
            else:
                written += write_notes(config, platform, version, detail, wanted)
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
