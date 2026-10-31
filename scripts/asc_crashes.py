"""Holt die TestFlight-Absturzmeldungen der App samt Bericht nur lesend ab (#773 Schnitt 1).

Aufruf: asc_crashes.py <zielordner>
Umgebung wie asc_wait_build.py (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, ASC_BUNDLE_ID, ASC_API_BASE,
ASC_POLL_SECONDS). Nur GET. Je Meldung <id>.json (Attribute wie geliefert) und, wenn Apple einen Bericht hat,
<id>.crash (logText), beide mit Modus 0600. Das Log nennt je Meldung nur Id, Bundle-ID, Plattform und Datum;
E-Mail, Kommentar, Gerätedaten, Berichtstext, Schlüssel und Token werden nie ausgegeben.
"""
import json
import os
import re
import sys
import time
import urllib.parse
from pathlib import Path

from asc_wait_build import Fatal, get_json, read_config

ATTEMPTS = 5
SAFE_ID = re.compile(r"^[A-Za-z0-9._-]+$")
SAFE_FIELD = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:+-]{0,63}")
NOT_FOUND = "ASC answered HTTP 404 for "


def fetch(config, path, valid=lambda body: True):
    """get_json mit bis zu fünf Versuchen; eine Antwort, die `valid` nicht erfüllt, zählt als nicht beantwortet."""
    for attempt in range(1, ATTEMPTS + 1):
        body = get_json(config, path)
        if body is not None and valid(body):
            return body
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"No answer from App Store Connect for {path.split('?')[0]}")


def app_id(config):
    """Id der App zur Bundle-ID über fetch (höchstens fünf Versuche); keine App ist Fatal."""
    query = urllib.parse.quote(config["bundle_id"], safe="")
    body = fetch(config, f"/v1/apps?filter[bundleId]={query}", lambda b: isinstance(b.get("data"), list) and (
        not b["data"] or (isinstance(b["data"][0], dict) and b["data"][0].get("id"))))
    if not body["data"]:
        raise Fatal(f"No app with bundle id {config['bundle_id']} in App Store Connect")
    return body["data"][0]["id"]


def next_path(body):
    """links.next als Pfad plus Abfrage (Apple liefert eine absolute Adresse), sonst None."""
    links = body.get("links")
    url = links.get("next") if isinstance(links, dict) else None
    if not url:
        return None
    parts = urllib.parse.urlsplit(url)
    return parts.path + (f"?{parts.query}" if parts.query else "")


def fetch_all(config, app_id):
    """Alle Meldungen über alle Seiten, ohne Plattformfilter; ein schon angefragter Pfad als links.next ist Fatal."""
    path, submissions = f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions?limit=200", []
    seen = set()
    while path:
        seen.add(path)
        body = fetch(config, path, lambda b: isinstance(b.get("data"), list))
        submissions.extend(body["data"])
        path = next_path(body)
        if path in seen:
            raise Fatal(f"Pagination loop at {path.split('?')[0]}")
    return submissions


def fetch_log(config, submission_id):
    """logText des Berichts; None ohne Bericht (404 oder leer). Jedes andere Fatal geht weiter."""
    try:
        body = fetch(config, f"/v1/betaFeedbackCrashSubmissions/{submission_id}/crashLog")
    except Fatal as error:
        if str(error).startswith(NOT_FOUND):
            return None
        raise
    data = body.get("data")
    attributes = data.get("attributes") if isinstance(data, dict) else None
    text = attributes.get("logText") if isinstance(attributes, dict) else None
    return text if isinstance(text, str) and text else None


def write_private(path, text):
    """Schreibt UTF-8 mit Modus 0600, auch wenn die Datei schon da war."""
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(text)


def collect(config, submissions):
    """(id, attributes, logText) je Meldung; prüft jede Id, bevor sie Pfad oder Anfrage wird."""
    entries = []
    for record in submissions:
        sid = record.get("id") if isinstance(record, dict) else None
        if not isinstance(sid, str) or not SAFE_ID.fullmatch(sid) or sid in (".", ".."):
            raise Fatal("Unexpected submission id")
        attributes = record.get("attributes")
        attributes = attributes if isinstance(attributes, dict) else {}
        entries.append((sid, attributes, fetch_log(config, sid)))
    return entries


def safe_field(value):
    """Nur ein sicherer str kommt in die Kennzeile (kein Zeilenumbruch, kein `::`, höchstens 64 Zeichen)."""
    if isinstance(value, str) and SAFE_FIELD.fullmatch(value) and "::" not in value:
        return value
    return "unbekannt"


def store(target, entries):
    """Schreibt die Dateien und druckt je Meldung die Kennzeile; gibt die Zahl mit Bericht zurück."""
    with_report = 0
    for sid, attributes, log in entries:
        write_private(target / f"{sid}.json", json.dumps(attributes, indent=2, sort_keys=True, ensure_ascii=False))
        crash = target / f"{sid}.crash"
        if log is None:
            crash.unlink(missing_ok=True)
        else:
            write_private(crash, log)
            with_report += 1
        fields = [safe_field(attributes.get(name)) for name in ("buildBundleId", "appPlatform", "createdDate")]
        print(f"meldung id={sid} bundle={fields[0]} plattform={fields[1]} datum={fields[2]} "
              f"bericht={'nein' if log is None else 'ja'}", flush=True)
    return with_report


def main(argv):
    if len(argv) != 2 or not argv[1].strip():
        print("usage: asc_crashes.py <target-folder>", file=sys.stderr)
        return 2
    target = Path(argv[1])
    try:
        target.mkdir(parents=True, exist_ok=True)
        config = read_config()
        entries = collect(config, fetch_all(config, app_id(config)))
        if not entries:
            print("keine Absturzmeldungen", flush=True)
            return 0
        with_report = store(target, entries)
        print(f"zusammenfassung meldungen={len(entries)} mit_bericht={with_report} "
              f"ohne_bericht={len(entries) - with_report}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1
    except OSError as error:
        print(f"::error::Cannot write {error.filename or 'target folder'}: {error.strerror}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
