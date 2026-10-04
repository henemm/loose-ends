"""Wartet, bis App Store Connect den Build mit der Lauf-Nummer als VALID meldet (#183).

Aufruf: asc_wait_build.py <build-nummer>
Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE (Pfad zur .p8), ASC_BUNDLE_ID, ASC_API_BASE,
ASC_POLL_SECONDS (30), ASC_TIMEOUT_SECONDS (2700 = 45 min).
Nur Standardbibliothek plus `openssl`. Schlüssel, Token und Signatur werden nie ausgegeben.
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DONE_BAD = ("FAILED", "INVALID")


class Fatal(Exception):
    """Abbruch mit Exit 1; die Meldung enthält nie Header, Token oder Schlüssel."""


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_rs(der):
    """ECDSA-Signatur von openssl (DER: SEQUENCE{INTEGER r, INTEGER s}) nach r‖s, je 32 Byte."""
    def read_int(pos):
        if der[pos] != 0x02:
            raise Fatal("openssl returned an unexpected signature format")
        length = der[pos + 1]
        value = der[pos + 2:pos + 2 + length].lstrip(b"\0")
        if len(value) > 32:
            raise Fatal("openssl returned an unexpected signature length")
        return value.rjust(32, b"\0"), pos + 2 + length

    if der[0] != 0x30:
        raise Fatal("openssl returned an unexpected signature format")
    start = 3 if der[1] & 0x80 else 2
    r, pos = read_int(start)
    s, _ = read_int(pos)
    return r + s


def make_token(key_id, issuer, key_file, now=None):
    """Neues ES256-Token, 10 Minuten gültig."""
    iat = int(now if now is not None else time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer, "iat": iat, "exp": iat + 600, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(claims).encode())}"
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_file],
                            input=signing_input.encode(), capture_output=True)
    if result.returncode != 0:
        raise Fatal(f"openssl could not sign with ASC_KEY_FILE (exit {result.returncode})")
    return f"{signing_input}.{b64url(der_to_rs(result.stdout))}"


def get_json(config, path):
    """GET gegen die ASC-API. None = diese Runde nicht beantwortet (5xx, 408, 429, Netz, Rumpf kein
    JSON-Objekt); 401/403 und andere 4xx = Fatal."""
    token = make_token(config["key_id"], config["issuer"], config["key_file"])
    request = urllib.request.Request(config["base"] + path, headers={"Authorization": f"Bearer {token}"})
    url_path = path.split("?")[0]
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read())
    except urllib.error.HTTPError as error:
        if error.code >= 500 or error.code in (408, 429):
            print(f"ASC answered HTTP {error.code} for {url_path}, retrying", flush=True)
            return None
        hint = " (check ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY and the key's role)" \
            if error.code in (401, 403) else ""
        raise Fatal(f"ASC answered HTTP {error.code} for {url_path}{hint}")
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        print(f"No answer from ASC for {url_path} ({type(error).__name__}), retrying", flush=True)
        return None
    except ValueError:
        print(f"ASC sent no JSON for {url_path}, retrying", flush=True)
        return None
    if not isinstance(body, dict):
        print(f"ASC sent an unexpected body for {url_path}, retrying", flush=True)
        return None
    return body


def find_app_id(config):
    query = urllib.parse.quote(config["bundle_id"], safe="")
    deadline = time.monotonic() + config["timeout"]
    while True:
        body = get_json(config, f"/v1/apps?filter[bundleId]={query}")
        apps = None if body is None else body.get("data") or []
        if isinstance(apps, list) and not apps:
            raise Fatal(f"No app with bundle id {config['bundle_id']} in App Store Connect")
        if isinstance(apps, list) and isinstance(apps[0], dict) and apps[0].get("id"):
            return apps[0]["id"]
        if body is not None:
            print("ASC sent an unexpected app lookup, retrying", flush=True)
        if time.monotonic() >= deadline:
            raise Fatal("App Store Connect did not answer the app lookup")
        time.sleep(config["poll"])


def record_count(body):
    """Zahl der Datensätze in Apples Antwort, vor dem eigenen Filtern auf version (AC-9)."""
    data = (body or {}).get("data")
    return len(data) if isinstance(data, list) else 0


def build_state(body, number):
    """(processingState, uploadedDate) des Datensatzes mit version == number, sonst None."""
    data = (body or {}).get("data")
    for record in data if isinstance(data, list) else []:
        attributes = record.get("attributes") if isinstance(record, dict) else None
        if not isinstance(attributes, dict):
            continue
        if attributes.get("version") == number:
            return attributes.get("processingState", "unbekannt"), attributes.get("uploadedDate", "unbekannt")
    return None


def duration(seconds):
    return f"{seconds / 60:g} min" if seconds >= 60 else f"{seconds:g} s"


def wait_for_build(config, app_id, number):
    """Fragt alle ASC_POLL_SECONDS ab; Exit-Code 0 nur bei VALID."""
    path = f"/v1/builds?filter[app]={app_id}&filter[version]={urllib.parse.quote(number, safe='')}"
    deadline = time.monotonic() + config["timeout"]
    last = "nicht-gelistet"
    while True:
        body = get_json(config, path)
        found, hits = build_state(body, number), record_count(body)
        if found is None:
            print(f"build={number} processingState=nicht-gelistet treffer={hits}", flush=True)
        else:
            last = found[0]
            print(f"build={number} processingState={found[0]} uploadedDate={found[1]} treffer={hits}", flush=True)
            if last == "VALID":
                return 0
            if last in DONE_BAD:
                raise Fatal(f"Build {number} is {last} in App Store Connect; see Apple's mail and the build in ASC")
        if time.monotonic() >= deadline:
            raise Fatal(f"Build {number} not VALID after {duration(config['timeout'])}, last state: {last}")
        time.sleep(config["poll"])


def read_config():
    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_FILE") if not os.environ.get(name)]
    if missing:
        raise Fatal(f"Missing environment: {', '.join(missing)}")
    return {
        "key_id": os.environ["ASC_KEY_ID"],
        "issuer": os.environ["ASC_ISSUER_ID"],
        "key_file": os.environ["ASC_KEY_FILE"],
        "bundle_id": os.environ.get("ASC_BUNDLE_ID", "com.henning.looseends"),
        "base": os.environ.get("ASC_API_BASE", "https://api.appstoreconnect.apple.com").rstrip("/"),
        "poll": float(os.environ.get("ASC_POLL_SECONDS", "30")),
        "timeout": float(os.environ.get("ASC_TIMEOUT_SECONDS", "2700")),
    }


def main(argv):
    if len(argv) != 2 or not argv[1].strip():
        print("usage: asc_wait_build.py <build-number>", file=sys.stderr)
        return 2
    number = argv[1].strip()
    try:
        config = read_config()
        return wait_for_build(config, find_app_id(config), number)
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
