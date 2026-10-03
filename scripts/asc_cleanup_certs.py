"""Widerruft die Entwicklungs-Zertifikate, die TestFlight-Läufe per API anlegen (#191).

Aufruf: asc_cleanup_certs.py [--dry-run]
Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE (Pfad zur .p8), ASC_API_BASE, GITHUB_STEP_SUMMARY (optional).
Gewählt wird nur certificateType DEVELOPMENT/IOS_DEVELOPMENT mit Anzeigename genau „Created via API“.
Nur Standardbibliothek plus `openssl`. Schlüssel, Token, Signatur und Zertifikatsinhalt werden nie ausgegeben.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

from asc_wait_build import Fatal, make_token

TYPES = ("DEVELOPMENT", "IOS_DEVELOPMENT")
NAME = "Created via API"


def request(config, method, url):
    """Eine Anfrage mit neuem Token; liefert (Status, JSON-Rumpf oder None). Kein Warten, keine Wiederholung."""
    if not url.startswith(config["base"] + "/"):
        raise Fatal(f"Refusing to follow a link to another host: {urllib.parse.urlsplit(url).netloc}")
    token = make_token(config["key_id"], config["issuer"], config["key_file"])
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, None
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise Fatal(f"No answer from ASC for {urllib.parse.urlsplit(url).path} ({type(error).__name__})")
    except ValueError:
        raise Fatal(f"ASC sent no JSON for {urllib.parse.urlsplit(url).path}")


def list_certs(config):
    """Alle Zertifikate über alle Seiten (links.next nur auf ASC_API_BASE)."""
    url, certs = config["base"] + "/v1/certificates?limit=200", []
    while url:
        status, body = request(config, "GET", url)
        if status != 200 or not isinstance(body, dict) or not isinstance(body.get("data"), list):
            hint = " (check ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY and the key's role: Admin)" \
                if status in (401, 403) else ""
            raise Fatal(f"ASC answered HTTP {status} for /v1/certificates{hint}")
        certs += [c for c in body["data"] if isinstance(c, dict)]
        links = body.get("links")
        url = links.get("next") if isinstance(links, dict) else None
    return certs


def attributes(cert):
    value = cert.get("attributes")
    return value if isinstance(value, dict) else {}


def display_name(cert):
    a = attributes(cert)
    name = a.get("name") if a.get("name") is not None else a.get("displayName")
    return name.strip() if isinstance(name, str) else None


def chosen(cert):
    """Enge Regel: Entwicklungs-Typ und Anzeigename genau „Created via API“; fehlt etwas, nie."""
    return attributes(cert).get("certificateType") in TYPES and display_name(cert) == NAME and bool(cert.get("id"))


def short(cid):
    return f"{str(cid)[:6]}…"


def show(certs):
    if certs:
        print(f"felder={','.join(sorted(attributes(certs[0])))}", flush=True)
    for cert in certs:
        a = attributes(cert)
        action = "widerruf" if chosen(cert) else "bleibt"
        print(f"typ={a.get('certificateType', 'fehlt')} name={display_name(cert) or 'fehlt'} "
              f"ablauf={a.get('expirationDate', 'fehlt')} id={short(cert.get('id', ''))} aktion={action}", flush=True)


def revoke(config, certs):
    """DELETE je gewähltem Zertifikat; Fehler werden laut gemeldet, die übrigen laufen weiter."""
    revoked, failed = 0, 0
    for cert in certs:
        url = f"{config['base']}/v1/certificates/{urllib.parse.quote(str(cert['id']), safe='')}"
        try:
            status, _ = request(config, "DELETE", url)
            reason = f"HTTP {status}"
        except Fatal as error:
            status, reason = None, str(error)
        if status in (200, 204):
            revoked += 1
        else:
            failed += 1
            print(f"::error::Revoking certificate {short(cert['id'])} failed: {reason}", flush=True)
    return revoked, failed


def report(line):
    print(line, flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")


def read_config():
    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_FILE") if not os.environ.get(name)]
    if missing:
        raise Fatal(f"Missing environment: {', '.join(missing)}")
    if not os.path.isfile(os.environ["ASC_KEY_FILE"]):
        raise Fatal("ASC_KEY_FILE does not exist")
    return {
        "key_id": os.environ["ASC_KEY_ID"],
        "issuer": os.environ["ASC_ISSUER_ID"],
        "key_file": os.environ["ASC_KEY_FILE"],
        "base": os.environ.get("ASC_API_BASE", "https://api.appstoreconnect.apple.com").rstrip("/"),
    }


def main(argv):
    dry_run = "--dry-run" in argv[1:]
    try:
        config = read_config()
        before = list_certs(config)
        show(before)
        wanted = [c for c in before if chosen(c)]
        if dry_run:
            report(f"zertifikate vorher={len(before)} nachher={len(before)} widerrufen=0 "
                   f"wuerde-widerrufen={len(wanted)}")
            return 0
        revoked, failed = revoke(config, wanted)
        report(f"zertifikate vorher={len(before)} nachher={len(list_certs(config))} widerrufen={revoked}")
        return 1 if failed else 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
