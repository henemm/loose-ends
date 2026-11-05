"""Täglicher Wächter für #837 AC-9 (#846): Sind die App-Infos schreibbar, oder hat Mac 1.0 die Prüfung verlassen?

Aufruf: asc_watch_appinfo.py
Umgebung wie asc_wait_build.py. Liest nur (GET). Gibt je App-Info und Version eine Zustandszeile aus, als letzte Zeile genau
`LAGE=editierbar|mac_fertig|warten`, bei GITHUB_OUTPUT auch dorthin. 5xx und Netzfehler bleiben still (LAGE=warten, Exit 0),
401/403 enden laut (Exit 1), damit ein abgelaufener Schlüssel auffällt. Schlüssel, Token und Apples Rohantworten nie.
"""
import os
import sys

from asc_app_info import EDITABLE, app_infos
from asc_beta_probe import attributes, records
from asc_wait_build import Fatal, find_app_id, read_config
from asc_what_to_test import get_data

IN_REVIEW = {"IN_REVIEW", "WAITING_FOR_REVIEW", "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}


def version_key(number):
    """`1.10` nach `1.9`; Teile ohne Zahl zählen als 0."""
    return tuple(int(part) if part.isdigit() else 0 for part in str(number or "").split("."))


def mac_state(versions):
    """Zustand der Mac-Version mit der höchsten versionString; None ohne Mac-Version."""
    macs = [attributes(item) for item in versions if attributes(item).get("platform") == "MAC_OS"]
    if not macs:
        return None
    return max(macs, key=lambda values: version_key(values.get("versionString"))).get("appStoreState")


def lage(infos, versions):
    """Rein: editierbar vor mac_fertig vor warten; fehlende Daten lösen nie etwas aus."""
    if any(attributes(item).get("state") == EDITABLE for item in infos):
        return "editierbar"
    state = mac_state(versions)
    return "mac_fertig" if state and state not in IN_REVIEW else "warten"


def report(infos, versions):
    for item in infos:
        print(f"appinfo id={item.get('id')} state={attributes(item).get('state') or '?'}", flush=True)
    for item in versions:
        values = attributes(item)
        print(f"version {values.get('platform') or '?'} {values.get('versionString') or '?'} "
              f"state={values.get('appStoreState') or '?'}", flush=True)


def announce(result, state=None):
    """Letzte Zeile LAGE=…; GITHUB_OUTPUT bekommt dazu den Mac-Zustand für den Kommentartext."""
    print(f"LAGE={result}", flush=True)
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as output:
            output.write(f"LAGE={result}\nMAC_STATE={state or '?'}\n")


def main():
    try:
        config = read_config()
        app_id = find_app_id(config)
        infos = app_infos(config, app_id)
        versions = records({"data": get_data(config, f"/v1/apps/{app_id}/appStoreVersions?limit=10")})
    except Fatal as error:
        if "HTTP 401" in str(error) or "HTTP 403" in str(error):
            print("::error::ASC lehnt den Schlüssel ab (HTTP 401/403): Schlüssel abgelaufen oder ohne Recht", flush=True)
            return 1
        print("::notice::ASC nicht erreichbar, nichts gemeldet", flush=True)
        announce("warten")
        return 0
    report(infos, versions)
    announce(lage(infos, versions), mac_state(versions))
    return 0


if __name__ == "__main__":
    sys.exit(main())
