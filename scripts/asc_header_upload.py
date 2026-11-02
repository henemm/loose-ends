"""Legt die Kopfbilder in Apples Asset-Bibliothek der App (#772, Teil B). Platziert nie, reicht nie ein.

Aufruf: asc_header_upload.py lesen|hochladen
Umgebung wie asc_wait_build.py. `lesen` holt nur Referenzdaten und Bibliothek (GET). `hochladen` nimmt die Bilder aus
docs/store/header/manifest.json, sucht je Bild die passende Spec über die Maße (sonst Abbruch vor jedem Schreiben),
legt fehlende an (POST, Bytes, `uploaded: true`) und wartet auf PREPARE_FOR_SUBMISSION. Schlüssel und Token werden nie
ausgegeben.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from asc_wait_build import Fatal, find_app_id, make_token, read_config

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / "docs/store/header"
READY = "PREPARE_FOR_SUBMISSION"
POLLS = 40
REFDATA = "/v1/appAssetLibraryRefData"
IMAGES = "/v1/appAssetLibraryImages"


def match_specs(specs, files):
    """Spec je Datei über Breite und Höhe; fehlt eine, Fatal mit allen vorhandenen Specs."""
    found = {}
    for item in files:
        hits = [s for s in specs if (s.get("width"), s.get("height")) == (item["width"], item["height"])]
        if not hits:
            listed = ", ".join(f"{s.get('category', '?')} {s.get('width', '?')}x{s.get('height', '?')}" for s in specs)
            raise Fatal(f"Keine Spec für {item['reference']} ({item['width']}x{item['height']}); "
                        f"vorhanden: {listed or 'keine'}")
        found[item["reference"]] = hits[0]["category"]
    return found


def wait_ready(client, image_id, sleep):
    for _ in range(POLLS):
        state = client.get(f"{IMAGES}/{image_id}").get("state")
        if state == READY:
            return
        sleep(15)
    raise Fatal(f"Bild {image_id} nach {POLLS} Abfragen nicht {READY}, zuletzt {state}")


def upload(client, app_id, files, sleep=time.sleep):
    """Nur Asset-Bibliothek: Anlegen, Bytes, `uploaded: true`, warten. Gibt das Ergebnis von check_state zurück."""
    library_path = f"/v1/apps/{app_id}/assetLibrary"
    library = client.get(library_path)
    categories = match_specs(client.get(REFDATA).get("imageSpecs") or [], files)
    existing = {image.get("referenceName") for image in library.get("images") or []}
    for item in files:
        if item["reference"] in existing:
            print(f"bild {item['reference']} schon vorhanden, übersprungen", flush=True)
            continue
        data = Path(item["path"]).read_bytes()
        created = client.post(IMAGES, {"fileName": Path(item["path"]).name, "fileSize": len(data),
                                       "category": categories[item["reference"]], "referenceName": item["reference"]})
        for operation in created.get("uploadOperations") or []:
            start = operation.get("offset", 0)
            chunk = data[start:start + operation.get("length", len(data))]
            headers = {h["name"]: h["value"] for h in operation.get("requestHeaders") or []}
            if headers:
                client.put(operation["url"], chunk, headers)
            else:
                client.put(operation["url"], chunk)
        client.patch(f"{IMAGES}/{created['id']}", {"uploaded": True})
        wait_ready(client, created["id"], sleep)
        print(f"bild {item['reference']} hochgeladen", flush=True)
    return check_state(client.get(library_path), [item["reference"] for item in files])


def check_state(library, names):
    """„bereit“ nur, wenn jedes Bild da ist, PREPARE_FOR_SUBMISSION trägt und nichts platziert ist; sonst Fatal."""
    if library.get("placements"):
        raise Fatal(f"Bibliothek hat {len(library['placements'])} Platzierung(en); dieses Skript platziert nie")
    states = {image.get("referenceName"): image.get("state") for image in library.get("images") or []}
    for name in names:
        if name not in states:
            raise Fatal(f"Bild {name} fehlt in der Bibliothek")
        if states[name] != READY:
            raise Fatal(f"Bild {name} ist {states[name]}, nicht {READY}")
    return "bereit"


def flat(record):
    return {"id": record.get("id"), **(record.get("attributes") or {})} if isinstance(record, dict) else record


class Client:
    """ASC-Zugang mit frischem Token je Anfrage; JSON:API-Datensätze kommen flach zurück (id + Attribute)."""

    def __init__(self, config, app_id):
        self.config, self.app_id = config, app_id

    def send(self, method, url, data=None, headers=None):
        request = urllib.request.Request(url, data=data, method=method, headers=headers or {})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            raise Fatal(f"ASC answered HTTP {error.code} for {method} {url.split('?')[0]}") from error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise Fatal(f"No answer for {method} {url.split('?')[0]} ({type(error).__name__})") from error
        return json.loads(raw) if raw else {}

    def api(self, method, path, body=None):
        token = make_token(self.config["key_id"], self.config["issuer"], self.config["key_file"])
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        data = json.dumps(body).encode() if body is not None else None
        return self.send(method, self.config["base"] + path, data, headers)

    def get(self, path):
        body = self.api("GET", path)
        data = body.get("data")
        if isinstance(data, list):
            return {"items": [flat(r) for r in data]}
        result = flat(data) if isinstance(data, dict) else {}
        for record in body.get("included") or []:
            key = "images" if "Image" in record.get("type", "") else "placements" if "lacement" in record.get("type", "") else None
            if key:
                result.setdefault(key, []).append(flat(record))
        return result

    def post(self, path, attributes):
        relationships = {"app": {"data": {"type": "apps", "id": self.app_id}}}
        kind = path.rsplit("/", 1)[1]
        return flat(self.api("POST", path, {"data": {"type": kind, "attributes": attributes,
                                                     "relationships": relationships}}).get("data"))

    def put(self, url, data, headers=None):
        self.send("PUT", url, data, headers)

    def patch(self, path, attributes):
        kind, image_id = path.rsplit("/", 2)[1:]
        return flat(self.api("PATCH", path, {"data": {"type": kind, "id": image_id, "attributes": attributes}})
                    .get("data"))


def header_files():
    manifest = json.loads((HEADER / "manifest.json").read_text())
    return [{"path": HEADER / e["file"], "reference": e["file"].removesuffix(".png"), "width": e["width"],
             "height": e["height"]} for e in manifest["files"]]


def main(argv):
    if len(argv) != 2 or argv[1] not in ("lesen", "hochladen"):
        print("usage: asc_header_upload.py lesen|hochladen", file=sys.stderr)
        return 2
    try:
        config = read_config()
        app_id = find_app_id(config)
        client = Client(config, app_id)
        if argv[1] == "lesen":
            for spec in client.get(REFDATA).get("imageSpecs") or []:
                print(f"spec kategorie={spec.get('category', '?')} maß={spec.get('width', '?')}x{spec.get('height', '?')}",
                      flush=True)
            library = client.get(f"/v1/apps/{app_id}/assetLibrary")
            for image in library.get("images") or []:
                print(f"bild name={image.get('referenceName', '?')} zustand={image.get('state', '?')}", flush=True)
            print(f"bibliothek felder={','.join(sorted(library)) or '-'} platzierungen={len(library.get('placements') or [])}",
                  flush=True)
            return 0
        print(f"zustand {upload(client, app_id, header_files())}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
