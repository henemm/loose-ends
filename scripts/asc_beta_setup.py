"""Setzt Beta-Beschreibung, Feedback-E-Mail und Review-Kontakt bei Apple (#705 Schnitt 2a).

Aufruf: asc_beta_setup.py
Umgebung wie asc_wait_build.py plus ASC_REVIEW_FIRST_NAME, ASC_REVIEW_LAST_NAME, ASC_REVIEW_PHONE, ASC_REVIEW_EMAIL
(Pflicht, die E-Mail ist auch feedbackEmail), ASC_PRIVACY_POLICY_URL (leer = nicht anfassen) und BETA_DESCRIPTION_FILE.
Liest zuerst, schreibt nur Abweichungen (idempotent). Ausgegeben werden nur „gesetzt/leer/unverändert“, nie Werte.
"""
import os
import sys
import time
from pathlib import Path

from asc_wait_build import Fatal, find_app_id, get_json, read_config
from asc_what_to_test import ATTEMPTS, LOCALE, MAX_LENGTH, get_data, send_json

CONTACT = {"contactFirstName": "ASC_REVIEW_FIRST_NAME", "contactLastName": "ASC_REVIEW_LAST_NAME",
           "contactPhone": "ASC_REVIEW_PHONE", "contactEmail": "ASC_REVIEW_EMAIL"}
DEFAULT_DESCRIPTION = Path(__file__).resolve().parent.parent / "docs" / "reference" / "beta-beschreibung.md"
FORBIDDEN = "Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen"


def wanted_values():
    """Gewünschte Werte aus der Umgebung und der Datei; prüft alles, bevor eine Anfrage läuft."""
    env = {name: os.environ.get(name, "").strip() for name in CONTACT.values()}
    missing = [name for name, value in env.items() if not value]
    if missing:
        raise Fatal(f"Missing environment: {', '.join(missing)}")
    if not env["ASC_REVIEW_PHONE"].startswith("+"):
        raise Fatal("ASC_REVIEW_PHONE must start with +")
    try:
        path = Path(os.environ.get("BETA_DESCRIPTION_FILE") or DEFAULT_DESCRIPTION)
        text = path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeDecodeError) as error:
        raise Fatal(f"BETA_DESCRIPTION_FILE is not readable ({type(error).__name__})")
    if not text or len(text) > MAX_LENGTH:
        raise Fatal(f"BETA_DESCRIPTION_FILE must hold 1 to {MAX_LENGTH} characters, has {len(text)}")
    localization = {"description": text, "feedbackEmail": env["ASC_REVIEW_EMAIL"]}
    privacy = os.environ.get("ASC_PRIVACY_POLICY_URL", "").strip()
    if privacy:
        localization["privacyPolicyUrl"] = privacy
    detail = {field: env[name] for field, name in CONTACT.items()} | {"demoAccountRequired": False}
    return localization, detail


def get_detail(config, app_id):
    """`data` des Review-Details; wiederholt wie get_data, solange ASC nicht antwortet (404 bleibt Fatal)."""
    path = f"/v1/apps/{app_id}/betaAppReviewDetail"
    for attempt in range(1, ATTEMPTS + 1):
        body = get_json(config, path)
        if body is not None:
            return body.get("data")
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    raise Fatal(f"App Store Connect did not answer {path}")


def differing(current, wanted):
    return {key: value for key, value in wanted.items() if current.get(key) != value}


def plan_localization(current, wanted):
    """current: Liste der Fassungen bei Apple. Plan: None, ("POST", Attribute) oder ("PATCH", id, Attribute)."""
    mine = [r for r in current if (r.get("attributes") or {}).get("locale") == LOCALE]
    if len(mine) > 1:
        raise Fatal(f"App Store Connect has {len(mine)} beta localizations {LOCALE}")
    if not mine:
        return ("POST", {"locale": LOCALE, **wanted})
    changed = differing(mine[0].get("attributes") or {}, wanted)
    return ("PATCH", mine[0]["id"], changed) if changed else None


def plan_review_detail(current, wanted):
    """current: Review-Detail bei Apple. Plan: None oder ("PATCH", id, Attribute)."""
    if not isinstance(current, dict) or not current.get("id"):
        raise Fatal("App Store Connect has no beta app review detail")
    changed = differing(current.get("attributes") or {}, wanted)
    return ("PATCH", current["id"], changed) if changed else None


def apply_plan(config, kind, plan, app_id=None):
    """Führt einen Plan aus; gibt die Zahl der Schreibaufrufe zurück."""
    if plan is None:
        return 0
    if plan[0] == "POST":
        payload = {"type": kind, "attributes": plan[1],
                   "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}
        path = f"/v1/{kind}"
    else:
        payload = {"type": kind, "id": plan[1], "attributes": plan[2]}
        path = f"/v1/{kind}/{plan[1]}"
    try:
        send_json(config, plan[0], path, {"data": payload})
    except Fatal as error:
        raise Fatal(FORBIDDEN) if "HTTP 403" in str(error) else error
    return 1


def state(key, plan, wanted, current):
    """Zustandswort eines Feldes: gesetzt (wird geschrieben), unverändert oder leer."""
    if plan and key in plan[-1]:
        return "gesetzt"
    return "unverändert" if key in wanted or current.get(key) else "leer"


def main(argv):
    try:
        loc_wanted, detail_wanted = wanted_values()
        config = read_config()
        app_id = find_app_id(config)
        localizations = get_data(config, f"/v1/apps/{app_id}/betaAppLocalizations")
        detail = get_detail(config, app_id)
        loc_plan = plan_localization(localizations, loc_wanted)
        detail_plan = plan_review_detail(detail, detail_wanted)
        mine = next((r.get("attributes") or {} for r in localizations
                     if (r.get("attributes") or {}).get("locale") == LOCALE), {})
        written = apply_plan(config, "betaAppLocalizations", loc_plan, app_id)
        written += apply_plan(config, "betaAppReviewDetails", detail_plan)
        words = [state(key, loc_plan, loc_wanted, mine) for key in ("description", "feedbackEmail", "privacyPolicyUrl")]
        print(f"lokalisierung locale={LOCALE} beschreibung={words[0]} feedbackEmail={words[1]} "
              f"datenschutzUrl={words[2]}", flush=True)
        contact = "gesetzt" if detail_plan and set(CONTACT) & set(detail_plan[2]) else "unverändert"
        print(f"reviewdetail kontakt={contact} demoAccountRequired=aus", flush=True)
        print(f"zusammenfassung geschrieben={written}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
