"""Liest und setzt die App-Review-Notizen von Version 1.0 (iOS) in App Store Connect (#788 Schnitt 1).

Aufruf: asc_review_notes.py lesen|notizen
Umgebung wie asc_wait_build.py plus REVIEW_NOTES_FILE (Standard docs/reference/app-review-notizen.md; der Text ist der
erste Codeblock darin). `lesen` schreibt nichts; `notizen` schreibt `notes` nur bei Abweichung und prüft danach gegen.
Ausgegeben werden nur Zustände und Bytezahlen, nie der Notes-Text oder Kontaktfelder (das Repo ist öffentlich).
"""
import os
import sys
import time
from pathlib import Path

from asc_beta_probe import attributes, records
from asc_wait_build import Fatal, find_app_id, get_json, read_config
from asc_what_to_test import ATTEMPTS, get_data, send_json

ACTIONS = ("lesen", "notizen")
MAX_BYTES = 4000
PLACEHOLDER = "<HIER_"
FENCE = "```"
VERSION_STRING = "1.0"
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


def find_version(config, app_id):
    """Die eine iOS-Version 1.0; keine oder mehrere sind ein Abbruch."""
    path = f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&filter[versionString]={VERSION_STRING}"
    found = [r for r in get_data(config, path) if isinstance(r, dict) and r.get("id")]
    if not found:
        raise Fatal(f"keine iOS-Version {VERSION_STRING} in App Store Connect")
    if len(found) > 1:
        raise Fatal(f"App Store Connect hat {len(found)} iOS-Versionen {VERSION_STRING}")
    state = attributes(found[0]).get("appStoreState") or "?"
    print(f"version {VERSION_STRING} IOS appStoreState={state}", flush=True)
    return found[0]["id"], state


def get_detail(config, version_id):
    """Das Review-Detail der Version; fehlt es (404 oder null), Abbruch ohne Anlegen."""
    path = f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail"
    missing = Fatal(f"Version {VERSION_STRING} hat keine App-Review-Informationen")
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


def read_state(config, detail):
    """Zustand der Notizen und Anhänge, ohne Werte."""
    print(notes_state(notes_of(detail)), flush=True)
    attachments = records({"data": get_data(config, f"/v1/appStoreReviewDetails/{detail['id']}/appStoreReviewAttachments")})
    for item in attachments:
        values = attributes(item)
        delivery = values.get("assetDeliveryState")
        state = delivery.get("state") if isinstance(delivery, dict) else None
        print(f"anhang name={values.get('fileName') or '?'} groesse={values.get('fileSize', '?')} "
              f"assetDeliveryState={state or '?'}", flush=True)
    if not attachments:
        print("anhang keine", flush=True)
    return 0


def write_notes(config, version_id, state, detail, wanted):
    """Schreibt `notes` nur bei Abweichung, prüft danach gegen; gibt die Zahl der Schreibaufrufe zurück."""
    size = len(wanted.encode("utf-8"))
    if notes_of(detail) == wanted:
        print(f"notizen unverändert bytes={size}", flush=True)
        return 0
    payload = {"data": {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": wanted}}}
    try:
        send_json(config, "PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", payload)
    except Fatal as error:
        if "HTTP 403" in str(error) or "HTTP 409" in str(error):
            raise Fatal(f"Apple lässt die Notizen im Zustand {state} nicht zu")
        raise
    print(f"notizen gesetzt bytes={size}", flush=True)
    if notes_of(get_detail(config, version_id)) != wanted:
        raise Fatal("Gegenprobe: die Notizen bei Apple weichen vom Wunschtext ab")
    print("gegenprobe gleich=ja", flush=True)
    return 1


def main(argv):
    try:
        if len(argv) != 2 or argv[1] not in ACTIONS:
            raise Fatal(f"Aufruf: asc_review_notes.py {'|'.join(ACTIONS)}")
        wanted = wanted_notes() if argv[1] == "notizen" else None
        config = read_config()
        version_id, state = find_version(config, find_app_id(config))
        detail = get_detail(config, version_id)
        if wanted is None:
            written = read_state(config, detail)
        else:
            written = write_notes(config, version_id, state, detail, wanted)
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
