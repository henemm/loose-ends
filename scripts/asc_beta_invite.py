"""Legt die externe TestFlight-Gruppe `Tester` an und ordnet ihr je Plattform den neuesten gültigen Build zu (#705 Schnitt 2b-1).

Aufruf: asc_beta_invite.py
Umgebung wie asc_wait_build.py (ASC_PLATFORM wird nicht gelesen, das Skript geht IOS und MAC_OS selbst durch).
Liest zuerst, schreibt nur Abweichungen (idempotent). Nie Einreichung zum Beta-Review, nie öffentlicher Link, nie DELETE
oder PATCH. Ausgegeben werden nur Zustandswörter, nie IDs, Buildnummern oder Links.
"""
import re
import sys

from asc_wait_build import Fatal, find_app_id, get_json, platform_filter, read_config
from asc_what_to_test import get_data, send_json

GROUP_NAME = "Tester"
PLATFORMS = ("IOS", "MAC_OS")
BUILD_QUERY = ("/v1/builds?filter[app]={app}&filter[processingState]=VALID&filter[expired]=false"
               "&sort=-uploadedDate&limit=1")
FORBIDDEN = "Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen"


def plan_group(groups):
    """groups: Beta-Gruppen der App. Plan: ("vorhanden", id) oder ("anlegen",); mehrere externe `Tester` = Fatal."""
    mine = [g["id"] for g in groups if (g.get("attributes") or {}).get("name") == GROUP_NAME
            and (g.get("attributes") or {}).get("isInternalGroup") is False]
    if len(mine) > 1:
        raise Fatal(f"App Store Connect has {len(mine)} external beta groups named {GROUP_NAME}")
    return ("vorhanden", mine[0]) if mine else ("anlegen",)


def plan_assignment(build_id, assigned_ids, group_id):
    """assigned_ids: IDs der Builds, die schon in der Gruppe liegen. Plan: None oder ("POST", Pfad, Rumpf)."""
    if build_id in assigned_ids:
        return None
    return ("POST", f"/v1/betaGroups/{group_id}/relationships/builds", {"data": [{"type": "builds", "id": build_id}]})


def apply_plan(config, plan):
    """Führt einen Plan aus; gibt die Zahl der Schreibaufrufe zurück."""
    if plan is None:
        return 0
    try:
        send_json(config, *plan)
    except Fatal as error:
        raise Fatal(FORBIDDEN) if "HTTP 403" in str(error) else error
    return 1


def message(error):
    """Text ohne Kennungen: jedes Pfadstück nach /v1/<art>/ und jeder Wert nach ?name= oder &name= wird zu …"""
    masked = re.sub(r"(/v1/\w+/)[^/\s?]+", r"\1…", str(error))
    return re.sub(r"([?&][^=\s&]+=)[^&\s]+", r"\1…", masked)


class Masked:
    """stdout, durch message() gefiltert: auch die Wiederholungszeilen der geteilten Helfer tragen keine IDs."""

    def __init__(self, stream):
        self.stream = stream

    def write(self, text):
        return self.stream.write(message(text))

    def flush(self):
        self.stream.flush()


def ensure_group(config, app_id):
    """Gruppe lesen und, falls sie fehlt, anlegen. Ergebnis: (Gruppen-ID, Zustandswort, Schreibaufrufe)."""
    path = f"/v1/apps/{app_id}/betaGroups"
    plan = plan_group(get_data(config, path))
    if plan[0] == "vorhanden":
        return plan[1], "vorhanden", 0
    attributes = {"name": GROUP_NAME, "isInternalGroup": False, "feedbackEnabled": True, "publicLinkEnabled": False}
    payload = {"data": {"type": "betaGroups", "attributes": attributes,
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    written = apply_plan(config, ("POST", "/v1/betaGroups", payload))
    # send_json liefert keinen Rumpf: die neue ID kommt aus dem erneuten Lesen
    plan = plan_group(get_data(config, path))
    if plan[0] != "vorhanden":
        raise Fatal(f"App Store Connect does not list the new beta group {GROUP_NAME}")
    return plan[1], "angelegt", written


def assign_platform(config, app_id, group_id, platform):
    """Neuesten gültigen Build der Plattform zuordnen. Ergebnis: (Schreibaufrufe, Ausgabezeile)."""
    scoped = dict(config, platform=platform)
    found = get_data(scoped, BUILD_QUERY.format(app=app_id) + platform_filter(scoped))
    if not found:
        return 0, f"zuordnung plattform={platform} zustand=kein-gültiger-build"
    build_id = found[0]["id"]
    # Apple kennt kein GET /v1/builds/{id}/betaGroups (403), nur die Build-Liste der Gruppe (Lauf 40516649071)
    members = get_data(config, f"/v1/betaGroups/{group_id}/relationships/builds?limit=200")
    plan = plan_assignment(build_id, {m.get("id") for m in members}, group_id)
    written = apply_plan(config, plan)
    try:
        detail = (get_json(config, f"/v1/builds/{build_id}/buildBetaDetail") or {}).get("data") or {}
    except Fatal:
        detail = {}  # die Zuordnung steht schon: ein unlesbarer Status darf den Schreibzähler nicht verlieren
    extern = (detail.get("attributes") or {}).get("externalBuildState", "unbekannt")
    word = "gesetzt" if written else "vorhanden"
    return written, f"zuordnung plattform={platform} zustand={word} extern={extern}"


def main(argv):
    try:
        config = read_config()
        app_id = find_app_id(config)
        group_id, word, written = ensure_group(config, app_id)
    except Fatal as error:
        # ohne Gruppe keine Zuordnung: Abbruch vor jedem Zuordnungsversuch
        print(f"::error::{message(error)}", flush=True)
        return 1
    print(f"gruppe name={GROUP_NAME} zustand={word}", flush=True)
    failed = False
    for platform in PLATFORMS:
        try:
            count, line = assign_platform(config, app_id, group_id, platform)
            written += count
            print(line, flush=True)
        except Fatal as error:
            failed = True
            print(f"::error::platform={platform} {message(error)}", flush=True)
    print(f"zusammenfassung geschrieben={written}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.stdout = Masked(sys.stdout)
    sys.exit(main(sys.argv))
