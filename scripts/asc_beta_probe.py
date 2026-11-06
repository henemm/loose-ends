"""Fragt Apples Beta-Seite der App nur lesend ab und druckt eine Belegtabelle (#705 Schnitt 1).

Aufruf: asc_beta_probe.py
Umgebung wie asc_wait_build.py (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, ASC_BUNDLE_ID, ASC_API_BASE,
ASC_PLATFORM, ASC_POLL_SECONDS). Nur GET. 403/404 einer Abfrage sind ein Befund (Exit 0); Exit 1 nur bei
Konfigurationsfehler oder wenn keine Abfrage antwortet. Kontaktwerte, Beschreibung, Feedback-E-Mail,
Datenschutz-URL, Schlüssel und Token werden nie ausgegeben, nur „gesetzt/leer“.
"""
import http.client
import json
import sys
import time
import urllib.error
import urllib.request

from asc_wait_build import Fatal, find_app_id, make_token, platform_filter, read_config

ATTEMPTS = 5
FINDING = '"Schlüssel hat keinen Zugriff oder Pfad unbekannt"'


def read_json(raw):
    """Rumpf als Dict, sonst None (kein JSON oder kein Objekt)."""
    try:
        body = json.loads(raw)
    except ValueError:
        return None
    return body if isinstance(body, dict) else None


def fetch(config, path):
    """GET; (Status, Rumpf, Fehlerrumpf). 2xx: (200, dict, None); 4xx: (4xx, None, dict|None) mit Apples
    Fehlerrumpf (#842); ohne Antwort nach allen Versuchen (None, None, None)."""
    url_path = path.split("?")[0]
    for attempt in range(1, ATTEMPTS + 1):
        token = make_token(config["key_id"], config["issuer"], config["key_file"])
        request = urllib.request.Request(config["base"] + path, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                status, raw = response.status, response.read()
            return status, read_json(raw) or {}, None
        except urllib.error.HTTPError as error:
            if not (error.code >= 500 or error.code in (408, 429)):
                try:
                    raw_error = error.read()
                except (OSError, http.client.HTTPException):
                    # Der Status ist der Befund; ein abgebrochener Fehlerrumpf nimmt nur den Grund weg (#842 F001).
                    raw_error = None
                return error.code, None, read_json(raw_error) if raw_error is not None else None
            print(f"ASC answered HTTP {error.code} for {url_path}, retrying", flush=True)
        except (urllib.error.URLError, TimeoutError, OSError, http.client.HTTPException) as error:
            print(f"No answer from ASC for {url_path} ({type(error).__name__}), retrying", flush=True)
        if attempt < ATTEMPTS:
            time.sleep(config["poll"])
    return None, None, None


def probe(config, path):
    """GET; (200, dict) bei Erfolg, (4xx, None) als Befund, (None, None) ohne Antwort nach allen Versuchen."""
    status, body, _ = fetch(config, path)
    return status, body


def reason(error_body):
    """` grund=<code>/<title>` des ersten Fehlers aus Apples Rumpf, nie `detail` (kann IDs nennen); sonst leer."""
    errors = (error_body or {}).get("errors")
    first = errors[0] if isinstance(errors, list) and errors and isinstance(errors[0], dict) else {}
    parts = [first.get(key) for key in ("code", "title")]
    if not all(isinstance(part, str) and part.strip() for part in parts):
        return ""
    text = "".join(char for char in "/".join(parts) if char.isprintable() and char not in "\"'")
    return f" grund={text.strip()[:80]}"


class Probe:
    """Stellt die Abfragen, druckt je eine Zugriffszeile und zählt Antworten und Befunde."""

    def __init__(self, config):
        self.config = config
        self.asked = self.answered = self.findings = 0

    def ask(self, name, path, build=None):
        status, body, error_body = fetch(self.config, path)
        self.asked += 1
        where = f" build={build}" if build is not None else ""
        if status is None:
            print(f"zugriff abfrage={name}{where} http=keine befund=\"keine Antwort\"", flush=True)
            return None
        self.answered += 1
        if not 200 <= status < 300:
            self.findings += 1
            hint = FINDING if status in (403, 404) else '"Apple lehnt die Abfrage ab"'
            print(f"zugriff abfrage={name}{where} http={status} befund={hint}{reason(error_body)}", flush=True)
            return None
        print(f"zugriff abfrage={name}{where} http={status}", flush=True)
        return body


def records(body):
    data = (body or {}).get("data")
    return [r for r in data if isinstance(r, dict)] if isinstance(data, list) else []


def attributes(record):
    value = (record or {}).get("attributes") if isinstance(record, dict) else None
    return value if isinstance(value, dict) else {}


def filled(value):
    """Booleans als an/aus, sonst gesetzt/leer; Leerzeichen, leere Listen und Dicts sind leer."""
    if isinstance(value, bool):
        return on_off(value)
    if isinstance(value, str):
        value = value.strip()
    return "leer" if value is None or value in ("", [], {}) else "gesetzt"


def on_off(value):
    return "an" if value else "aus"


def report_groups(run, app_id):
    body = run.ask("betaGroups", f"/v1/apps/{app_id}/betaGroups")
    if body is None:
        return
    groups = records(body)
    if not groups:
        print("gruppe keine", flush=True)
    for group in groups:
        a = attributes(group)
        link = a.get("publicLink") if a.get("publicLinkEnabled") else None
        url = "gesetzt" if filled(link) == "gesetzt" else "-"
        print(f"gruppe name={a.get('name', '?')} intern={'ja' if a.get('isInternalGroup') else 'nein'} "
              f"link={on_off(a.get('publicLinkEnabled'))} url={url} "
              f"feedback={on_off(a.get('feedbackEnabled'))}", flush=True)


def report_review_detail(run, app_id):
    body = run.ask("betaAppReviewDetail", f"/v1/apps/{app_id}/betaAppReviewDetail")
    if body is None:
        return
    a = attributes(body.get("data"))
    fields = " ".join(f"{name}={filled(value)}" for name, value in a.items())
    print(f"reviewdetail attribute={','.join(a) or '-'} {fields}".rstrip(), flush=True)


def report_localizations(run, app_id):
    body = run.ask("betaAppLocalizations", f"/v1/apps/{app_id}/betaAppLocalizations")
    if body is None:
        return
    entries = records(body)
    if not entries:
        print("lokalisierung keine", flush=True)
    for entry in entries:
        a = attributes(entry)
        print(f"lokalisierung locale={a.get('locale', '?')} beschreibung={filled(a.get('description'))} "
              f"feedbackEmail={filled(a.get('feedbackEmail'))} "
              f"datenschutzUrl={filled(a.get('privacyPolicyUrl'))}", flush=True)


def report_build(run, record):
    """Build-Zeile mit Prüfstatus; gibt die Zahl der gefundenen Einreichungen zurück."""
    a, build_id = attributes(record), record.get("id", "?")
    number = a.get("version", "?")
    detail = attributes((run.ask("buildBetaDetail", f"/v1/builds/{build_id}/buildBetaDetail", number) or {})
                        .get("data"))
    linked = run.ask("betaAppReviewSubmission", f"/v1/builds/{build_id}/betaAppReviewSubmission", number)
    linked_state = attributes((linked or {}).get("data")).get("betaReviewState") or "keine"
    platform = a.get("platform") or run.config.get("platform") or "unbekannt"
    print(f"build nummer={number} plattform={platform} processingState={a.get('processingState', '?')} "
          f"intern={detail.get('internalBuildState', '?')} extern={detail.get('externalBuildState', '?')} "
          f"einreichung={linked_state}", flush=True)
    found = records(run.ask("betaAppReviewSubmissions", f"/v1/betaAppReviewSubmissions?filter[build]={build_id}",
                            number))
    for submission in found:
        print(f"einreichung build={number} zustand={attributes(submission).get('betaReviewState', '?')}",
              flush=True)
    return len(found)


def report_builds(run, app_id):
    path = f"/v1/builds?filter[app]={app_id}&sort=-version&limit=5{platform_filter(run.config)}"
    body = run.ask("builds", path)
    if body is None:
        return
    builds = records(body)
    if not builds:
        print("build keine", flush=True)
    submissions = sum(report_build(run, record) for record in builds)
    if not submissions:
        print("einreichung keine", flush=True)


def main(argv):
    try:
        config = read_config()
        app_id = find_app_id(config)
        run = Probe(config)
        report_groups(run, app_id)
        report_review_detail(run, app_id)
        report_localizations(run, app_id)
        report_builds(run, app_id)
        print(f"zusammenfassung antworten={run.answered} von={run.asked} befunde={run.findings}", flush=True)
        if not run.answered:
            raise Fatal("App Store Connect answered none of the beta queries")
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
