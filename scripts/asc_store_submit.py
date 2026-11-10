"""Vorprüfung und Einreichen der App-Store-Versionen zur Prüfung bei Apple (#893 Schnitt A und B).

Aufruf: asc_store_submit.py pruefen | asc_store_submit.py einreichen <nummer>
Umgebung wie asc_version_texts.py. `pruefen` liest nur (GET) und wertet beide Plattformen vollständig aus: genau eine
bearbeitbare Version (PREPARE_FOR_SUBMISSION) mit gleicher Nummer auf beiden Plattformen, Bau zugeordnet, gültig, nicht
abgelaufen und zur Version passend, Texte de-DE und en-US, Bilder je Locale, Review-Detail und die Einreichungen der
Plattform. Je Plattform `<Plattform> bereit` oder je Grund `<Plattform> nicht-bereit: <Grund>`; Ausgang 0 nur, wenn
beide bereit sind. Ausgegeben werden nur Zustandswörter und Zeichenzahlen: nie Schlüssel, Token, Kennungen, Apples
Rohantwort oder Store-Wortlaut. `pruefen` schreibt nichts und reicht nichts ein.
`einreichen <nummer>` (Schnitt B): die Nummer ist die Bestätigung und muss der Zielversion gleichen. Erst ein Plan
beider Plattformen (nur GET), ein einziger Grund hält beide an; dann je Plattform, iOS zuerst, Einreichung anlegen oder
die eine READY_FOR_REVIEW wiederverwenden, die Version als Item, abschicken, Gegenprobe. Jeder Schreibaufruf genau
einmal, nie wiederholt; eine schon eingereichte Plattform wird übersprungen. Das Skript löscht und storniert nie.
"""
import http.client
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from asc_beta_invite import Masked
from asc_beta_probe import attributes, records
from asc_store_version import count, current_build, get_one
from asc_version_texts import EDITABLE, PLATFORMS, app_versions, localizations
from asc_wait_build import Fatal, find_app_id, make_token, read_config
from asc_what_to_test import get_data

LOCALES = ("de-DE", "en-US")
REQUIRED = ("description", "keywords", "supportUrl", "whatsNew")
SIZES = ("description", "keywords", "supportUrl", "whatsNew", "promotionalText")
BUSY = ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES", "CANCELING", "COMPLETING")
REUSABLE = "READY_FOR_REVIEW"
DONE = "COMPLETE"
SHORT = {"IOS": "ios", "MAC_OS": "mac"}
SUBMITTED = ("WAITING_FOR_REVIEW", "IN_REVIEW")
VERIFY_ATTEMPTS = 6


def mask(text):
    """Regel von asc_beta_invite.message (Pfadstück nach /v1/<art>/ und Abfragewert werden zu …), nur der schon
    bereinigte Platzhalter <id> aus den Gründen bleibt stehen; er ist keine Kennung."""
    masked = re.sub(r"(/v1/\w+/)(?!<id>(?:[/\s=,;]|$))[^/\s?]+", r"\1…", str(text))
    return re.sub(r"([?&][^=\s&]+=)[^&\s]+", r"\1…", masked)


class Watched(Masked):
    """Masked-Ausgabe, die den Status der letzten Wiederholungszeile der geteilten Helfer merkt: nach 5xx nennt
    deren Fatal keinen Status mehr, der Grund `nicht lesbar HTTP <status>` braucht ihn trotzdem."""
    last = None

    def write(self, text):
        found = re.search(r"ASC answered HTTP (\d+)", text)
        if found:
            Watched.last = found.group(1)
        return self.stream.write(mask(text))


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
    return rows


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
    return check_submissions(config, app_id, platform, reasons, notes)


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


def related_version(row):
    """Kennung der Version eines Items; jedes andere Item (anderer Typ, ohne Daten) → None."""
    relation = ((row.get("relationships") or {}).get("appStoreVersion") or {}) if isinstance(row, dict) else {}
    data = relation.get("data") if isinstance(relation, dict) else None
    return data.get("id") if isinstance(data, dict) and data.get("type") == "appStoreVersions" else None


def item_targets(config, sub_id):
    """Versionen der Items einer Einreichung, je Item eine Kennung oder None (fremd)."""
    path = f"/v1/reviewSubmissions/{sub_id}/items?include=appStoreVersion&limit=50"
    return [related_version(row) for row in records({"data": get_data(config, path)})]


def mine(rows, platform, states):
    """Einreichungen der Plattform (ohne Plattformangabe mitgezählt) in einem der Zustände."""
    return [row for row in rows or [] if attributes(row).get("platform") in (None, platform)
            and attributes(row).get("state") in states]


def submitted_plan(config, app_id, platform, versions, number):
    """Schon eingereicht: genau eine Version mit der Nummer in WAITING_FOR_REVIEW/IN_REVIEW und genau eine solche
    Einreichung, deren einziges Item diese Version ist. Sonst None."""
    done = [item for item in versions if attributes(item).get("platform") == platform
            and attributes(item).get("versionString") == number and attributes(item).get("appStoreState") in SUBMITTED]
    if len(done) != 1:
        return None
    rows = mine(submissions(config, app_id, platform), platform, SUBMITTED)
    if len(rows) != 1 or item_targets(config, rows[0]["id"]) != [done[0]["id"]]:
        return None
    return {"state": "eingereicht", "reasons": [], "notes": [], "version": done[0], "submission": rows[0]["id"]}


def plan_platform(config, app_id, platform, versions, number):
    """Plan einer Plattform, nur GET: eingereicht, sonst die Prüfungen von `pruefen` plus Bestätigung und die Items der
    wiederverwendbaren Einreichung (Fremdes ist ein Grund, gelöscht wird nie)."""
    plan = submitted_plan(config, app_id, platform, versions, number)
    if plan:
        return plan
    plan = {"state": "offen", "reasons": [], "notes": [], "version": None, "submission": None, "has_item": False}
    rows = check_platform(config, app_id, platform, versions, plan["reasons"], plan["notes"])
    found = editable_for(versions, platform)[0]
    if len(found) == 1:
        plan["version"] = found[0]
        if (attributes(found[0]).get("versionString") or "?") != number:
            plan["reasons"].append(f"bestätigung ungleich versionsnummer {attributes(found[0]).get('versionString')}")
    ready = mine(rows, platform, (REUSABLE,))
    if plan["reasons"] or len(ready) != 1:
        return plan
    targets = item_targets(config, ready[0]["id"])
    if targets not in ([], [plan["version"]["id"]]):
        plan["reasons"].append(f"einreichung {REUSABLE} mit fremdem Item, nichts gelöscht")
    plan["submission"], plan["has_item"] = ready[0]["id"], bool(targets)
    return plan


def report_plan(plans):
    """Zeilen je Plattform wie bei `pruefen`, dazu `eingereicht` und die Freigabeart; setzt `bereit` und gibt die
    nicht bereiten Plattformen zurück."""
    for platform, plan in plans.items():
        for note in plan["notes"]:
            print(f"{platform} hinweis: {note}", flush=True)
        for reason in plan["reasons"]:
            print(f"{platform} nicht-bereit: {reason}", flush=True)
        if plan["state"] == "offen" and not plan["reasons"]:
            plan["state"] = "bereit"
        if plan["state"] in ("eingereicht", "bereit"):
            print(f"{platform} {plan['state']}", flush=True)
            print(f"{platform} freigabeart {attributes(plan['version']).get('releaseType') or '?'}", flush=True)
    return [SHORT[p] for p, plan in plans.items() if plan["state"] not in ("eingereicht", "bereit")]


CODE = re.compile(r"[A-Z0-9_.]+")
ID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[A-Za-z0-9]*[0-9]{4,}[A-Za-z0-9]*")
PATH = re.compile(r"[A-Za-z0-9/_.<>-]{1,60}")
KEY = re.compile(r"[A-Za-z0-9_<>]+")
REASON_CODE = re.compile(r"[A-Za-z0-9_.<>]{1,80}")


def error_body(error):
    """Den Rumpf einer Fehlerantwort genau einmal lesen; jede Störung ergibt ein leeres Dict."""
    try:
        body = json.loads(error.read(8192))
    except (ValueError, TypeError, OSError, AttributeError):
        return {}
    return body if isinstance(body, dict) else {}


def error_entries(body):
    errors = body.get("errors")
    return [entry for entry in errors if isinstance(entry, dict)] if isinstance(errors, list) else []


def main_codes(body):
    """Apples Hauptcodes (Regel wie error_codes: Whitelist, höchstens 5), nie title/detail."""
    return [entry["code"] for entry in error_entries(body)
            if isinstance(entry.get("code"), str) and CODE.fullmatch(entry["code"])][:5]


def reason_code(item):
    code = item.get("code")
    if not isinstance(code, str):
        return "?"
    cleaned = ID.sub("<id>", code)
    return cleaned if REASON_CODE.fullmatch(cleaned) else "?"


def reason_path(path):
    if not isinstance(path, str):
        return "?"
    cleaned = ID.sub("<id>", path)
    return cleaned if PATH.fullmatch(cleaned) else "?"


def reason_pairs(associated):
    """(Pfad, Code) aus meta.associatedErrors, Form Objekt (Pfad -> Liste) oder Liste; anderes ergibt nichts."""
    if isinstance(associated, dict):
        return [(reason_path(path), reason_code(item)) for path, items in associated.items()
                if isinstance(items, list) for item in items if isinstance(item, dict)]
    if isinstance(associated, list):
        pairs = []
        for item in associated:
            if isinstance(item, dict):
                source = item.get("source") if isinstance(item.get("source"), dict) else {}
                pairs.append((reason_path(source.get("pointer") or source.get("parameter")), reason_code(item)))
        return pairs
    return []


def associated_reasons(body):
    """Zusatz zur Fehlermeldung: `; gründe: <pfad>=<code>, …` (höchstens 8, ohne Dubletten) oder bei unbekannter
    Form `; meta: <schlüsselnamen>`. Liest nie title, detail oder Werte; jede Störung ergibt ``."""
    try:
        pairs, keys = [], []
        for entry in error_entries(body):
            meta = entry.get("meta")
            if not isinstance(meta, dict):
                continue
            for pair in reason_pairs(meta.get("associatedErrors")):
                if pair not in pairs:
                    pairs.append(pair)
            cleaned = [ID.sub("<id>", key) for key in meta if isinstance(key, str)]
            keys += [key for key in dict.fromkeys(cleaned) if KEY.fullmatch(key) and key not in keys]
        if pairs:
            return "; gründe: " + ", ".join(f"{path}={code}" for path, code in pairs[:8])
        if keys:
            return "; meta: " + ", ".join(keys[:8])
    except (AttributeError, TypeError, ValueError):
        pass
    return ""


def send_once(config, method, path, payload):
    """Genau ein Schreibaufruf, nie wiederholt (Muster post_submission): auch 5xx, 408, 429 und Netzfehler enden mit
    Fatal, damit nie eine zweite Einreichung entsteht. Rückgabe: der Rumpf; 4xx nennt nur Apples Fehlercodes."""
    token = make_token(config["key_id"], config["issuer"], config["key_file"])
    request = urllib.request.Request(config["base"] + path, data=json.dumps(payload).encode(), method=method,
                                     headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        body = error_body(error)
        codes = main_codes(body)
        suffix = f" (codes: {', '.join(codes)})" if codes else ""
        raise Fatal(f"ASC antwortet HTTP {error.code} für {method} {path}{suffix}{associated_reasons(body)}, "
                    "nicht wiederholt")
    except (urllib.error.URLError, http.client.HTTPException, TimeoutError, OSError) as error:
        raise Fatal(f"Keine Antwort von ASC für {method} {path} ({type(error).__name__}), nicht wiederholt")
    try:
        body = json.loads(raw or b"{}")
    except ValueError:
        body = {}
    return body if isinstance(body, dict) else {}


def write_platform(config, app_id, platform, plan):
    """Einreichung anlegen oder wiederverwenden, Version als Item, abschicken; gibt die Einreichung zurück."""
    sub_id, version_id = plan["submission"], plan["version"]["id"]
    if sub_id is None:
        body = send_once(config, "POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": platform},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        data = body.get("data")
        sub_id = data.get("id") if isinstance(data, dict) else None
        if not sub_id:
            raise Fatal(f"{platform} einreichung angelegt, Antwort ohne Kennung; der nächste Lauf verwendet sie wieder")
        print(f"{platform} schritt einreichung angelegt", flush=True)
    else:
        print(f"{platform} schritt einreichung wiederverwendet", flush=True)
    if plan["has_item"]:
        print(f"{platform} schritt item vorhanden", flush=True)
    else:
        send_once(config, "POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        print(f"{platform} schritt item hinzugefügt", flush=True)
    send_once(config, "PATCH", f"/v1/reviewSubmissions/{sub_id}", {"data": {
        "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    print(f"{platform} schritt abgeschickt", flush=True)
    return sub_id


def verify_platform(config, platform, sub_id, version_id):
    """Gegenprobe: Einreichung und Version WAITING_FOR_REVIEW oder IN_REVIEW; Apple darf verzögert sein, daher
    begrenztes Nachlesen im Abstand ASC_POLL_SECONDS. Nimmt nie etwas zurück."""
    for attempt in range(1, VERIFY_ATTEMPTS + 1):
        sub_state = attributes(get_one(config, f"/v1/reviewSubmissions/{sub_id}")).get("state") or "?"
        version_state = attributes(get_one(config, f"/v1/appStoreVersions/{version_id}")).get("appStoreState") or "?"
        if sub_state in SUBMITTED and version_state in SUBMITTED:
            break
        if attempt < VERIFY_ATTEMPTS:
            time.sleep(config["poll"])
    print(f"{platform} gegenprobe einreichung={sub_state} version={version_state}", flush=True)
    return sub_state in SUBMITTED and version_state in SUBMITTED


def einreichen(config, app_id, number):
    """Plan beider Plattformen (nur GET), dann je Plattform iOS zuerst schreiben und gegenprüfen; Ausgang 0 nur, wenn
    beide nach der Gegenprobe eingereicht sind."""
    if not number.strip():
        print("::error::Bestätigung fehlt: Versionsnummer der Zielversion angeben", flush=True)
        return 1
    versions = app_versions(config, app_id)
    plans = {platform: plan_platform(config, app_id, platform, versions, number) for platform in PLATFORMS}
    same_number(versions, {platform: plan["reasons"] for platform, plan in plans.items()})
    blocked = report_plan(plans)
    if blocked:
        print(f"::error::nicht bereit: {','.join(blocked)}, nichts eingereicht", flush=True)
        return 1
    done = []
    try:
        for platform, plan in plans.items():
            if plan["state"] == "bereit":
                plan["submission"] = write_platform(config, app_id, platform, plan)
            if not verify_platform(config, platform, plan["submission"], plan["version"]["id"]):
                print(f"zusammenfassung eingereicht={','.join(done) or 'keine'}", flush=True)
                print(f"::error::gegenprobe {platform} nicht eingereicht", flush=True)
                return 1
            done.append(SHORT[platform])
    except Fatal:
        print(f"zusammenfassung eingereicht={','.join(done) or 'keine'}", flush=True)
        raise
    print(f"zusammenfassung eingereicht={','.join(done)}", flush=True)
    return 0


ACTIONS = {"pruefen": (pruefen, 0), "einreichen": (einreichen, 1)}


def main(argv):
    if len(argv) < 2 or argv[1] not in ACTIONS or len(argv) != 2 + ACTIONS[argv[1]][1]:
        print("::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>", flush=True)
        return 1
    try:
        config = read_config()
        app_id = find_app_id(config)
    except Fatal as error:
        print(f"::error::{mask(error)}", flush=True)
        return 1
    try:
        return ACTIONS[argv[1]][0](config, app_id, *argv[2:])
    except Fatal as error:
        print(f"::error::{mask(error)}", flush=True)
        return 1


if __name__ == "__main__":
    sys.stdout = Watched(sys.stdout)
    sys.exit(main(sys.argv))
