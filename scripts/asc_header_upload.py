"""Legt die Kopfbilder in Apples Asset-Bibliothek der App (#772, Teil B). Platziert nie, reicht nie ein.

Aufruf: asc_header_upload.py lesen|hochladen
Umgebung wie asc_wait_build.py. `lesen` holt nur Referenzdaten und Bibliothek (GET). `hochladen` nimmt die Bilder aus
docs/store/header/manifest.json, sucht je Bild eine Kopf-Spec, in deren Maßspannen es liegt (passt keines, Abbruch vor
jedem Schreiben; übrige als ::warning::), legt fehlende an (POST, Bytes, `uploaded: true`) und wartet auf
PREPARE_FOR_SUBMISSION. Form nach App Store Connect API 4.5.0. Schlüssel und Token werden nie ausgegeben.
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
REFDATA = "/v1/appAssetLibraryRefData/1"
IMAGES = "/v1/appAssetLibraryImages"
HEADER_TYPE = "PRODUCT_PAGE_HEADER_ASSET"


def describe(spec):
    d = spec.get("dimensions") or {}
    return (f"{spec.get('specId', '?')} {d.get('minWidth', '?')}-{d.get('maxWidth', '?')}x"
            f"{d.get('minHeight', '?')}-{d.get('maxHeight', '?')} {','.join(spec.get('compatiblePlacementTypes') or [])}")


def fits(spec, item):
    d = spec.get("dimensions") or {}
    return (HEADER_TYPE in (spec.get("compatiblePlacementTypes") or [])
            and d.get("minWidth", 0) <= item["width"] <= d.get("maxWidth", -1)
            and d.get("minHeight", 0) <= item["height"] <= d.get("maxHeight", -1))


def match_specs(refdata, files):
    """Kategorie je Datei, deren Maß in den Spannen einer Kopf-Spec liegt; dazu die Dateien ohne passende Spec."""
    accepted = [c for t in refdata.get("placementTypes") or [] if t.get("placementTypeId") == HEADER_TYPE
                for c in t.get("acceptsAssetCategories") or []]
    specs = refdata.get("imageSpecs") or []
    found, unmatched = {}, []
    for item in files:
        if accepted and any(fits(spec, item) for spec in specs):
            found[item["reference"]] = accepted[0]
        else:
            unmatched.append(item)
    return found, unmatched


def wait_ready(client, image_id, sleep):
    for _ in range(POLLS):
        image = client.get(f"{IMAGES}/{image_id}")
        state = image.get("state")
        if state == READY:
            return
        if state == "FAILED":
            raise Fatal(f"Bild {image_id} ist FAILED: {image.get('stateDetails', '?')}")
        sleep(15)
    raise Fatal(f"Bild {image_id} nach {POLLS} Abfragen nicht {READY}, zuletzt {state}")


def put_bytes(client, created, data):
    for operation in created.get("uploadOperations") or []:
        start = operation.get("offset", 0)
        chunk = data[start:start + operation.get("length", len(data))]
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders") or []}
        if headers:
            client.put(operation["url"], chunk, headers)
        else:
            client.put(operation["url"], chunk)


def upload(client, app_id, files, sleep=time.sleep):
    """Nur Asset-Bibliothek: Anlegen, Bytes, `uploaded: true`, warten. Gibt das Ergebnis von check_state zurück."""
    refdata = client.get(REFDATA)
    categories, unmatched = match_specs(refdata, files)
    if not categories:
        names = ", ".join(f"{i['reference']} ({i['width']}x{i['height']})" for i in files)
        listed = "; ".join(describe(s) for s in refdata.get("imageSpecs") or [])
        raise Fatal(f"Keine Spec für {names}; vorhanden: {listed or 'keine'}")
    for item in unmatched:
        print(f"::warning::Keine Kopf-Spec für {item['reference']} ({item['width']}x{item['height']}), nicht hochgeladen",
              flush=True)
    library_id = client.get(f"/v1/apps/{app_id}/assetLibrary")["id"]
    existing = {i.get("referenceName") for i in client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]}
    relationship = {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library_id}}}
    fitting = [item for item in files if item["reference"] in categories]
    for item in fitting:
        if item["reference"] in existing:
            print(f"bild {item['reference']} schon vorhanden, übersprungen", flush=True)
            continue
        data = Path(item["path"]).read_bytes()
        created = client.post(IMAGES, {"fileName": Path(item["path"]).name, "fileSize": len(data),
                                       "category": categories[item["reference"]], "referenceName": item["reference"]},
                              relationship)
        put_bytes(client, created, data)
        client.patch(f"{IMAGES}/{created['id']}", {"uploaded": True})
        wait_ready(client, created["id"], sleep)
        print(f"bild {item['reference']} hochgeladen", flush=True)
    return check_state(client, library_id, [item["reference"] for item in fitting])


def check_state(client, library_id, names):
    """„bereit“ nur, wenn jedes Bild da ist, PREPARE_FOR_SUBMISSION trägt und nichts platziert ist; sonst Fatal."""
    images = {i.get("referenceName"): i for i in client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]}
    for name in names:
        if name not in images:
            raise Fatal(f"Bild {name} fehlt in der Bibliothek")
        if images[name].get("state") != READY:
            raise Fatal(f"Bild {name} ist {images[name].get('state')}, nicht {READY}")
        placements = client.get(f"{IMAGES}/{images[name]['id']}/placements")["items"]
        if placements:
            raise Fatal(f"Bild {name} hat {len(placements)} Platzierung(en); dieses Skript platziert nie")
    return "bereit"


def lesen(client, app_id):
    """Nur GET: rohe Specs, Platzierungstypen mit Kategorien, Bilder mit Zustand und Zahl der Platzierungen."""
    refdata = client.get(REFDATA)
    print(f"refdata felder={','.join(sorted(refdata)) or '-'}", flush=True)
    for spec in refdata.get("imageSpecs") or []:
        print(f"spec {describe(spec)}", flush=True)
    for kind in refdata.get("placementTypes") or []:
        print(f"platzierungstyp {kind.get('placementTypeId', '?')} "
              f"kategorien={','.join(kind.get('acceptsAssetCategories') or []) or '-'}", flush=True)
    library = client.get(f"/v1/apps/{app_id}/assetLibrary")
    print(f"bibliothek id={library.get('id', '?')} felder={','.join(sorted(library)) or '-'}", flush=True)
    for image in client.get(f"/v1/appAssetLibraries/{library.get('id')}/images")["items"]:
        placements = client.get(f"{IMAGES}/{image.get('id')}/placements")["items"]
        print(f"bild name={image.get('referenceName', '?')} zustand={image.get('state', '?')} "
              f"details={image.get('stateDetails', '-')} platzierungen={len(placements)} "
              f"felder={','.join(sorted(image))}", flush=True)


def flat(record):
    return {"id": record.get("id"), **(record.get("attributes") or {})} if isinstance(record, dict) else record


def error_codes(error):
    """`errors[].code` aus Apples Fehlerantwort (etwa STATE_ERROR.INVALID_STATE); leer, wenn die Antwort keine trägt."""
    try:
        body = json.loads(error.read() or b"{}")
    except (ValueError, OSError):
        return ""
    errors = body.get("errors") if isinstance(body, dict) else None
    return ", ".join(str(e["code"]) for e in errors or [] if isinstance(e, dict) and e.get("code"))


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
            codes = error_codes(error)
            raise Fatal(f"ASC answered HTTP {error.code} for {method} {url.split('?')[0]}"
                        + (f" ({codes})" if codes else "")) from error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise Fatal(f"No answer for {method} {url.split('?')[0]} ({type(error).__name__})") from error
        return json.loads(raw) if raw else {}

    def api(self, method, path, body=None):
        token = make_token(self.config["key_id"], self.config["issuer"], self.config["key_file"])
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        data = json.dumps(body).encode() if body is not None else None
        return self.send(method, self.config["base"] + path, data, headers)

    def get(self, path):
        data = self.api("GET", path).get("data")
        if isinstance(data, list):
            return {"items": [flat(r) for r in data]}
        return flat(data) if isinstance(data, dict) else {}

    def post(self, path, attributes, relationships):
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
            lesen(client, app_id)
            return 0
        print(f"zustand {upload(client, app_id, header_files())}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
