"""Schaltet den öffentlichen Einladungslink der externen TestFlight-Gruppe `Tester` ein oder aus (#705 Schnitt 2b-2c).

Aufruf: asc_beta_link.py [--aus] (jedes andere Argument: nichts lesen, nichts schreiben, Exit 2)
Umgebung wie asc_beta_invite.py (ASC_PLATFORM wird nicht gelesen, das Skript geht IOS und MAC_OS selbst durch).
Ohne Schalter: nur wenn je Plattform der neueste gültige Build in der Gruppe liegt und `BETA_APPROVED` ist, genau ein PATCH
mit Link an und Limit 50; danach Gegenlesen, und stimmt das Limit nicht, sofort wieder aus (Exit 1). Mit --aus: Link aus,
falls er an ist. Liest zuerst, schreibt nur Abweichungen (idempotent). Ausgegeben werden nur Zustandswörter, nie der Link,
IDs oder Buildnummern.
"""
import sys

from asc_beta_invite import BUILD_QUERY, GROUP_NAME, PLATFORMS, Masked, apply_plan, message, plan_group, read_extern
from asc_wait_build import Fatal, find_app_id, platform_filter, read_config
from asc_what_to_test import get_data

LIMIT = 50
APPROVED = "BETA_APPROVED"
SWITCH_ON = {"publicLinkEnabled": True, "publicLinkLimitEnabled": True, "publicLinkLimit": LIMIT}
SWITCH_OFF = {"publicLinkEnabled": False}
ALLOWED_ARGS = ([], ["--aus"])


def confirmed(attributes):
    """Link an, Limit an, Limit genau 50. Ein fehlendes Feld zählt wie ein abweichendes, eine andere Form wie keins."""
    if not isinstance(attributes, dict):
        return False
    limit = attributes.get("publicLinkLimit")
    return (attributes.get("publicLinkEnabled") is True and attributes.get("publicLinkLimitEnabled") is True
            and isinstance(limit, int) and not isinstance(limit, bool) and limit == LIMIT)


def plan_link(attributes, readiness):
    """readiness: {Plattform: None (kein gültiger Build) oder Zustand}. Plan: ("vorhanden",), ("nicht-bereit", [(P, Wert)])
    oder ("einschalten",)."""
    if confirmed(attributes):
        return ("vorhanden",)
    if all(state is None for state in readiness.values()):
        return ("nicht-bereit", [("keine", "kein-gültiger-build")])
    blocked = [(platform, state) for platform, state in readiness.items() if state is not None and state != APPROVED]
    return ("nicht-bereit", blocked) if blocked else ("einschalten",)


def read_group(config, app_id):
    """Externe Gruppe `Tester` lesen. Ergebnis: (Gruppen-ID, Attribute als dict); fehlt sie oder hat die Antwort eine
    unerwartete Form, Fatal."""
    groups = get_data(config, f"/v1/apps/{app_id}/betaGroups")
    try:
        plan = plan_group(groups)
        group = next((g for g in groups if plan[0] == "vorhanden" and g.get("id") == plan[1]), None)
    except (AttributeError, KeyError, TypeError):  # Element ohne Objektform, Gruppe ohne id, Attribute als Liste
        raise Fatal(f"App Store Connect sent an unreadable answer for beta group {GROUP_NAME}") from None
    if group is None:
        raise Fatal(f"App Store Connect has no external beta group {GROUP_NAME}")
    attributes = group.get("attributes")
    return plan[1], attributes if isinstance(attributes, dict) else {}


def platform_state(config, app_id, group_id, platform):
    """Neuester gültiger Build der Plattform. Ergebnis: None (keiner), `nicht-in-gruppe` oder externalBuildState."""
    scoped = dict(config, platform=platform)
    found = get_data(scoped, BUILD_QUERY.format(app=app_id) + platform_filter(scoped))
    if not found:
        return None
    members = get_data(config, f"/v1/betaGroups/{group_id}/relationships/builds?limit=200")
    if found[0]["id"] not in {m.get("id") for m in members}:
        return "nicht-in-gruppe"  # der Link gilt nur für Builds der Gruppe
    return read_extern(config, found[0]["id"])


def patch(config, group_id, attributes, sent):
    """Genau ein PATCH auf die Gruppe; 4xx wird nicht wiederholt. sent zählt die angenommenen Aufrufe."""
    payload = {"data": {"type": "betaGroups", "id": group_id, "attributes": dict(attributes)}}
    sent.append(apply_plan(config, ("PATCH", f"/v1/betaGroups/{group_id}", payload)))


def undo_failed_enable(config, app_id, group_id, sent):
    """Der Einschalt-PATCH ist gescheitert, Apple kann ihn trotzdem angewendet haben (5xx, Netzfehler). Steht der Link an
    oder ist die Gruppe nicht lesbar, wird er ausgeschaltet; steht er aus, geht nichts mehr raus."""
    try:
        _, attributes = read_group(config, app_id)
    except Exception:  # nicht lesbar oder unerwartete Form zählt wie an
        attributes = {"publicLinkEnabled": True}
    if attributes.get("publicLinkEnabled") is True:
        patch(config, group_id, SWITCH_OFF, sent)


def switch_on(config, app_id, group_id, sent):
    """Einschalten, gegenlesen, bei Abweichung zurückschalten. Ergebnis: (Ausgabezeile, Erfolg)."""
    try:
        patch(config, group_id, SWITCH_ON, sent)
    except Exception as error:  # auch ein abgerissener Aufruf kann angewendet sein
        try:
            undo_failed_enable(config, app_id, group_id, sent)
        except Exception as undo:  # nicht verschlucken, aber die Ursprungsmeldung bleibt die ausgegebene ::error::
            print(f"link zustand=ausschalten-gescheitert grund={message(undo)}", flush=True)
        raise error
    try:
        _, attributes = read_group(config, app_id)
    except Exception:  # nicht lesbar oder unerwartete Form zählt wie ein abweichendes Limit: nie ein Link ohne Limit
        attributes = {}
    if confirmed(attributes):
        return f"link zustand=eingeschaltet limit={LIMIT}", True
    try:
        patch(config, group_id, SWITCH_OFF, sent)
    except Exception as error:  # der Link kann noch an sein: laut melden, nie „abgebrochen“
        print(f"link zustand=ausschalten-gescheitert grund={message(error)}", flush=True)
        raise
    return "link zustand=abgebrochen grund=limit", False


def enable(config, app_id, group_id, attributes, sent):
    """Vorbedingungen lesen, dann höchstens einschalten. Ergebnis: (Ausgabezeilen, Erfolg)."""
    readiness = {}
    if not confirmed(attributes):  # steht der Link schon richtig, braucht es keine Build-Abfrage
        for platform in PLATFORMS:
            readiness[platform] = platform_state(config, app_id, group_id, platform)
            if readiness[platform] is None:
                print(f"link plattform={platform} zustand=kein-gültiger-build", flush=True)
    plan = plan_link(attributes, readiness)
    if plan[0] == "vorhanden":
        return f"link zustand=vorhanden limit={LIMIT}", True
    if plan[0] == "nicht-bereit":
        return "\n".join(f"link zustand=nicht-bereit plattform={p} extern={state}" for p, state in plan[1]), True
    return switch_on(config, app_id, group_id, sent)


def disable(config, group_id, attributes, sent):
    """Link aus, außer er steht ausdrücklich aus; jeder andere Wert wird ausgeschaltet. Ergebnis: (Ausgabezeile, Erfolg)."""
    if attributes.get("publicLinkEnabled") is False:
        return "link zustand=vorhanden aus", True
    patch(config, group_id, SWITCH_OFF, sent)
    return "link zustand=ausgeschaltet", True


def main(argv):
    sent = []
    if argv[1:] not in ALLOWED_ARGS:  # ein Tippfehler darf den Link nie einschalten
        print("::error::unbekanntes Argument, erlaubt sind nur kein Argument oder --aus", flush=True)
        print("zusammenfassung geschrieben=0", flush=True)
        return 2
    try:
        config = read_config()
        app_id = find_app_id(config)
        # ohne Gruppe kein Schreiben: read_group bricht vor jedem PATCH ab
        group_id, attributes = read_group(config, app_id)
        if argv[1:] == ["--aus"]:
            line, ok = disable(config, group_id, attributes, sent)
        else:
            line, ok = enable(config, app_id, group_id, attributes, sent)
        print(line, flush=True)
    except Exception as error:  # nichts Unerwartetes verlässt das Skript als Traceback: der könnte IDs tragen
        ok = False
        print(f"::error::{message(error)}", flush=True)
    print(f"zusammenfassung geschrieben={sum(sent)}", flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.stdout = Masked(sys.stdout)
    sys.exit(main(sys.argv))
