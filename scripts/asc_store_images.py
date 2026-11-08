"""Legt die Store-Bilder einer Sprache in Apples Asset-Bibliothek der App (#842, 4c-1). Platziert nie, reicht nie ein.

Aufruf: asc_store_images.py lesen|hochladen de|en
Umgebung wie asc_wait_build.py. Quelle ist docs/store/screenshots/<sprache>/manifest.json; jedes Bild heißt
`<sprache>-<gerät>-<datei ohne .png>`. Vor jedem Schreiben geprüft: genau eine bearbeitbare iOS-Version, deren
Lokalisierung der Sprache, Datei und Pixelmaß laut Manifest, Gruppe und maxCount in den Referenzdaten. `lesen` ruft nur
GET; `hochladen` legt fehlende Bilder an (POST, Bytes, `uploaded: true`) und wartet auf PREPARE_FOR_SUBMISSION. Ohne
bearbeitbare Mac-Version bleibt der Mac mit ::warning:: aus. Schlüssel und Token werden nie ausgegeben.
"""
import json
import struct
import sys
import time
from pathlib import Path

from asc_header_upload import IMAGES, REFDATA, Client, check_state, put_bytes, wait_ready
from asc_locales import ASC_LOCALES
from asc_version_texts import app_versions, editable_version, localizations
from asc_wait_build import Fatal, find_app_id, read_config

SCREENSHOTS = Path(__file__).resolve().parent.parent / "docs/store/screenshots"
ACTIONS = ("lesen", "hochladen")
SPRACHEN = ("de", "en")
SHOT = "APP_SCREENSHOT"
FEATURE = "APP_STORE_VERSIONS"
GROUPS = {"iphone": "IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE", "ipad": "IPAD_13_PROFILE",
          "watch": "WATCH_SERIES_10_PROFILE"}


def plan(sprache, root=SCREENSHOTS):
    """Je Bild des Manifests Pfad, Gruppe, Soll-Maß und Name; Geräte ohne feste Gruppe (Mac) bleiben aus."""
    base = Path(root) / sprache
    manifest = json.loads((base / "manifest.json").read_text())
    entries = []
    for device in manifest["geraete"]:
        if device["geraet"] not in GROUPS:
            continue
        width, height = (int(n) for n in device["pixel"].split("x"))
        for name in device["dateien"]:
            entries.append({"reference": f"{sprache}-{device['geraet']}-{name.removesuffix('.png')}",
                            "group": GROUPS[device["geraet"]], "path": base / device["ordner"] / name,
                            "width": width, "height": height})
    return entries


def png_size(path):
    """Breite und Höhe aus dem IHDR-Kopf eines PNG."""
    head = Path(path).read_bytes()[:24]
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise Fatal(f"Datei {path} ist kein PNG")
    return struct.unpack(">II", head[16:24])


def screenshot_rules(refdata):
    """maxCount je Gruppe der App-Store-Version und die akzeptierte Kategorie für APP_SCREENSHOT."""
    limits = {group: limit.get("maxCount", 0)
              for feature in refdata.get("features") or [] if feature.get("featureId") == FEATURE
              for policy in feature.get("placementPolicies") or [] if policy.get("placementType") == SHOT
              for limit in policy.get("groupLimits") or [] for group in limit.get("groupIds") or []}
    categories = [c for t in refdata.get("placementTypes") or [] if t.get("placementTypeId") == SHOT
                  for c in t.get("acceptsAssetCategories") or []]
    return limits, categories[0] if categories else None


def warn_mac(versions):
    if editable_version(versions, "MAC_OS") is None:
        print("::warning::keine bearbeitbare Mac-Version, Mac-Bilder nicht hochgeladen", flush=True)
    else:
        print("::warning::Mac-Version bearbeitbar, Mac-Bilder sind nicht Teil dieses Laufs", flush=True)


def preflight(client, sprache, versions, lookup, root):
    """Alle Prüfungen vor dem ersten Schreiben, nur GET; gibt Plan und Kategorie zurück oder Fatal."""
    version = editable_version(versions, "IOS")
    if version is None:
        raise Fatal("keine bearbeitbare Version IOS, nichts geschrieben")
    locale = ASC_LOCALES[sprache]
    if locale not in lookup(version["id"]):
        raise Fatal(f"Version {version['id']} hat keine Lokalisierung {locale}, nichts geschrieben")
    entries = plan(sprache, root)
    for entry in entries:
        if not Path(entry["path"]).is_file():
            raise Fatal(f"Datei {entry['path']} fehlt, nichts geschrieben")
        width, height = png_size(entry["path"])
        if (width, height) != (entry["width"], entry["height"]):
            raise Fatal(f"Datei {entry['path']} ist {width}x{height}, Manifest {entry['width']}x{entry['height']}")
    limits, category = screenshot_rules(client.get(REFDATA))
    for group in dict.fromkeys(entry["group"] for entry in entries):
        count = sum(1 for entry in entries if entry["group"] == group)
        if group not in limits:
            raise Fatal(f"Gruppe {group} fehlt in den Referenzdaten, nichts geschrieben")
        if count > limits[group]:
            raise Fatal(f"Gruppe {group}: {count} Bilder, maxCount {limits[group]}, nichts geschrieben")
    if category is None:
        raise Fatal(f"keine Kategorie für {SHOT} in den Referenzdaten, nichts geschrieben")
    return entries, category


def upload(client, app_id, sprache, versions, lookup, sleep=time.sleep, root=SCREENSHOTS):
    """Nur Asset-Bibliothek: Anlegen, Bytes, `uploaded: true`, warten. Gibt das Ergebnis von check_state zurück."""
    entries, category = preflight(client, sprache, versions, lookup, root)
    warn_mac(versions)
    library_id = client.get(f"/v1/apps/{app_id}/assetLibrary")["id"]
    existing = {i.get("referenceName") for i in client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]}
    relationship = {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library_id}}}
    for entry in entries:
        name = entry["reference"]
        if name in existing:
            print(f"bild {name} schon vorhanden, übersprungen", flush=True)
            continue
        data = Path(entry["path"]).read_bytes()
        created = client.post(IMAGES, {"fileName": Path(entry["path"]).name, "fileSize": len(data),
                                       "category": category, "referenceName": name}, relationship)
        put_bytes(client, created, data)
        client.patch(f"{IMAGES}/{created['id']}", {"uploaded": True})
        try:
            wait_ready(client, created["id"], sleep)
        except Fatal as error:
            raise Fatal(f"{name}: {error}") from error
        print(f"bild {name} hochgeladen", flush=True)
    return check_state(client, library_id, [entry["reference"] for entry in entries])


def lesen(client, app_id, sprache, versions, lookup, root=SCREENSHOTS):
    """Nur GET: Version, Lokalisierung, Gruppen mit maxCount, Bestand der Bibliothek, Plan vorhanden/fehlt, Mac."""
    version = editable_version(versions, "IOS")
    locale = ASC_LOCALES[sprache]
    if version is not None:
        found = locale in lookup(version["id"])
        print(f"lokalisierung {locale} {'vorhanden' if found else 'fehlt'}", flush=True)
    entries = plan(sprache, root)
    limits, category = screenshot_rules(client.get(REFDATA))
    print(f"kategorie {SHOT}={category or '-'}", flush=True)
    for group in dict.fromkeys(entry["group"] for entry in entries):
        state = f"vorhanden maxCount={limits[group]}" if group in limits else "fehlt"
        print(f"gruppe {group} {state}", flush=True)
    library_id = client.get(f"/v1/apps/{app_id}/assetLibrary").get("id")
    images = client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]
    for image in images:
        placements = client.get(f"{IMAGES}/{image.get('id')}/placements")["items"]
        print(f"bild name={image.get('referenceName', '?')} zustand={image.get('state', '?')} "
              f"platzierungen={len(placements)}", flush=True)
    names = {image.get("referenceName") for image in images}
    for entry in entries:
        print(f"plan {entry['reference']} {'vorhanden' if entry['reference'] in names else 'fehlt'}", flush=True)
    warn_mac(versions)


def main(argv):
    if len(argv) != 3 or argv[1] not in ACTIONS or argv[2] not in SPRACHEN:
        print(f"usage: asc_store_images.py {'|'.join(ACTIONS)} {'|'.join(SPRACHEN)}", file=sys.stderr)
        return 2
    action, sprache = argv[1], argv[2]
    try:
        config = read_config()
        app_id = find_app_id(config)
        client = Client(config, app_id)
        versions = app_versions(config, app_id)
        lookup = lambda version_id: localizations(config, version_id)  # noqa: E731
        if action == "lesen":
            lesen(client, app_id, sprache, versions, lookup)
            return 0
        print(f"zustand {upload(client, app_id, sprache, versions, lookup)}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
