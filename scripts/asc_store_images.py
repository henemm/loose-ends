"""Legt die Store-Bilder einer Sprache in Apples Asset-Bibliothek der App (#842, 4c-1) und platziert die englischen auf der
en-US-Seite der bearbeitbaren iOS-Version (4c-2), mit `mac` die Mac-Bilder auf die der bearbeitbaren Mac-Version (5b).
Löscht nie, reicht nie ein, beschreibt de-DE nie.

Aufruf: asc_store_images.py lesen|hochladen de|en [ios|mac], asc_store_images.py platzieren en [ios|mac]
Umgebung wie asc_wait_build.py. Quelle ist docs/store/screenshots/<sprache>/manifest.json; jedes Bild heißt
`<sprache>-<gerät>-<datei ohne .png>`. Ein Lauf bedient genau eine Plattform (ohne Angabe iOS) und liest und beschreibt
nur deren Gruppen. Vor jedem Schreiben geprüft: genau eine bearbeitbare Version der Plattform, deren
Lokalisierung der Sprache, Datei und Pixelmaß laut Manifest, Gruppe und maxCount in den Referenzdaten. `lesen` ruft nur
GET; `hochladen` legt fehlende Bilder an (POST, Bytes, `uploaded: true`) und wartet auf PREPARE_FOR_SUBMISSION. Ohne
Der iOS-Lauf nennt den Mac mit ::warning::. `platzieren` prüft erst nur mit GET (Bilder bereit, en-US-Bestand
nur aus Plan-Bildern, jedes höchstens einmal), legt fehlende Platzierungen an, wartet, ordnet nur bei Abweichung und prüft
gegen; de-DE wird nur gelesen. Schlüssel und Token werden nie ausgegeben.
"""
import json
import os
import struct
import sys
import time
from pathlib import Path

from asc_header_upload import IMAGES, POLLS, READY, REFDATA, Client, put_bytes, wait_ready
from asc_locales import ASC_LOCALES
from asc_version_texts import app_versions, editable_version, localizations
from asc_wait_build import Fatal, find_app_id, read_config

SCREENSHOTS = Path(__file__).resolve().parent.parent / "docs/store/screenshots"
ACTIONS = ("lesen", "hochladen", "platzieren")
SPRACHEN = ("de", "en")
SHOT = "APP_SCREENSHOT"
FEATURE = "APP_STORE_VERSIONS"
PLACEMENTS = "/v1/appAssetLibraryPlacements"
ORDERING = "/v1/appAssetLibraryPlacementOrderingRequests"
GROUPS = {"iphone": "IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE", "ipad": "IPAD_13_PROFILE",
          "watch": "WATCH_SERIES_10_PROFILE", "mac": "MAC_PROFILE"}
PLATTFORMEN = {"ios": {"iphone", "ipad", "watch"}, "mac": {"mac"}}
ASC_PLATFORM = {"ios": "IOS", "mac": "MAC_OS"}


def plan(sprache, root=SCREENSHOTS, plattform="ios"):
    """Je Bild des Manifests Pfad, Gruppe, Soll-Maß und Name; nur Geräte der Plattform."""
    base = Path(root) / sprache
    manifest = json.loads((base / "manifest.json").read_text())
    entries = []
    for device in manifest["geraete"]:
        if device["geraet"] not in PLATTFORMEN[plattform]:
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


def warn_mac(versions, plattform):
    """Nur im iOS-Lauf: nennt den Mac, der mit dem dritten Argument `mac` einen eigenen Lauf hat."""
    if plattform != "ios":
        return
    if editable_version(versions, "MAC_OS") is None:
        print("::warning::keine bearbeitbare Mac-Version, Mac-Bilder nicht hochgeladen", flush=True)
    else:
        print("::warning::Mac-Version bearbeitbar, Mac-Bilder sind nicht Teil dieses Laufs (… mac)", flush=True)


def platform_version(versions, plattform):
    """Die eine bearbeitbare Version der Plattform oder Fatal."""
    version = editable_version(versions, ASC_PLATFORM[plattform])
    if version is None:
        raise Fatal(f"keine bearbeitbare Version {ASC_PLATFORM[plattform]}, nichts geschrieben")
    return version


def preflight(client, sprache, versions, lookup, root, plattform="ios"):
    """Alle Prüfungen vor dem ersten Schreiben, nur GET; gibt Plan, Kategorie und Lokalisierungen zurück oder Fatal."""
    version = platform_version(versions, plattform)
    locale, locs = ASC_LOCALES[sprache], lookup(version["id"])
    if locale not in locs:
        raise Fatal(f"Version {version['id']} hat keine Lokalisierung {locale}, nichts geschrieben")
    entries = plan(sprache, root, plattform)
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
    return entries, category, locs


def upload(client, app_id, sprache, versions, lookup, sleep=time.sleep, root=SCREENSHOTS, plattform="ios"):
    """Nur Asset-Bibliothek: Anlegen, Bytes, `uploaded: true`, warten. Gibt das Ergebnis von check_state zurück."""
    entries, category, _ = preflight(client, sprache, versions, lookup, root, plattform)
    warn_mac(versions, plattform)
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
    return check_ready(client, library_id, [entry["reference"] for entry in entries])


def ready_images(client, library_id, names):
    """Jedes Bild da und PREPARE_FOR_SUBMISSION, Platzierung erlaubt; gibt {Name: Bild} zurück oder Fatal."""
    images = {i.get("referenceName"): i for i in client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]}
    for name in names:
        if name not in images:
            raise Fatal(f"Bild {name} fehlt in der Bibliothek")
        if images[name].get("state") != READY:
            raise Fatal(f"Bild {name} ist {images[name].get('state')}, nicht {READY}")
    return images


def check_ready(client, library_id, names):
    ready_images(client, library_id, names)
    return "bereit"


def lesen(client, app_id, sprache, versions, lookup, root=SCREENSHOTS, plattform="ios"):
    """Nur GET: Version, Lokalisierung, Gruppen mit maxCount, Bestand der Bibliothek, Plan vorhanden/fehlt, Mac."""
    version = editable_version(versions, ASC_PLATFORM[plattform])
    locale, locs, found = ASC_LOCALES[sprache], {}, False
    if version is not None:
        locs = lookup(version["id"])
        found = locale in locs
        print(f"lokalisierung {locale} {'vorhanden' if found else 'fehlt'}", flush=True)
    entries = plan(sprache, root, plattform)
    limits, category = screenshot_rules(client.get(REFDATA))
    print(f"kategorie {SHOT}={category or '-'}", flush=True)
    for group in dict.fromkeys(entry["group"] for entry in entries):
        state = f"vorhanden maxCount={limits[group]}" if group in limits else "fehlt"
        print(f"gruppe {group} {state}", flush=True)
    library_id = client.get(f"/v1/apps/{app_id}/assetLibrary").get("id")
    images = client.get(f"/v1/appAssetLibraries/{library_id}/images")["items"]
    owner = {}
    for image in images:
        placements = client.get(f"{IMAGES}/{image.get('id')}/placements")["items"]
        owner.update({placement["id"]: image.get("referenceName") for placement in placements})
        print(f"bild name={image.get('referenceName', '?')} zustand={image.get('state', '?')} "
              f"platzierungen={len(placements)}", flush=True)
    names = {image.get("referenceName") for image in images}
    for entry in entries:
        print(f"plan {entry['reference']} {'vorhanden' if entry['reference'] in names else 'fehlt'}", flush=True)
    if sprache == "en" and found:
        print_placements(client, locs[locale]["id"], entries, owner)
    warn_mac(versions, plattform)


def owners(client, images):
    """Platzierungs-ID → Bildname über die Platzierungen je Bibliotheksbild (ohne `included`)."""
    return {placement["id"]: image.get("referenceName") for image in images
            for placement in client.get(f"{IMAGES}/{image.get('id')}/placements")["items"]}


def read_group(client, loc_id, group, owner):
    """Platzierungen einer Gruppe in Anzeigereihenfolge als (ID, Bildname oder None, Datensatz)."""
    path = (f"/v1/appStoreVersionLocalizations/{loc_id}/placements?filter[placementType]={SHOT}"
            f"&filter[placementGroup]={group}&sort=placementGroupPosition&limit=200")
    return [(item["id"], owner.get(item["id"]), item) for item in client.get(path)["items"]]


def grouped(entries):
    groups = {}
    for entry in entries:
        groups.setdefault(entry["group"], []).append(entry["reference"])
    return groups


def check_existing(current, want):
    """Bestand je Gruppe nur aus Plan-Bildern, jedes höchstens einmal; sonst Fatal, nichts geschrieben."""
    for group, rows in current.items():
        names = [name for _, name, _ in rows]
        for placement_id, name, _ in rows:
            if name not in want[group]:
                raise Fatal(f"Gruppe {group}: fremde Platzierung {name or placement_id}, nichts geschrieben")
        for name in names:
            if names.count(name) > 1:
                raise Fatal(f"Gruppe {group}: {name} ist {names.count(name)}x platziert, nichts geschrieben")


def german_counts(client, locs, groups):
    """de-DE nur gelesen: Anzahl je Gruppe der Plattform, z. B. `5/5/2` (iOS) oder `4` (Mac)."""
    if "de-DE" not in locs:
        return None
    return "/".join(str(len(client.get(f"/v1/appStoreVersionLocalizations/{locs['de-DE']['id']}/placements"
                                       f"?filter[placementType]={SHOT}&filter[placementGroup]={group}"
                                       f"&sort=placementGroupPosition&limit=200")["items"])) for group in groups)


def good(state):
    return state == "ACTIVE" or str(state).startswith("PARENT_")


def wait_placements(client, pending, sleep):
    """Pollt jede Platzierung bis ACTIVE oder PARENT_*; ASSET_PROCESSING wartet, alles andere ist Fatal."""
    seconds = float(os.environ.get("ASC_POLL_SECONDS", "15"))
    for placement_id, name in pending.items():
        for _ in range(POLLS):
            placement = client.get(f"{PLACEMENTS}/{placement_id}")
            state = placement.get("state")
            if good(state):
                break
            if state != "ASSET_PROCESSING":
                raise Fatal(f"Platzierung {name} ist {state}: {placement.get('stateDetails', '-')}")
            sleep(seconds)
        else:
            raise Fatal(f"Platzierung {name} nach {POLLS} Abfragen noch ASSET_PROCESSING")


def create_missing(client, loc_id, images, want, current):
    """Legt je Plan-Bild ohne eigene Platzierung eine an, Gruppe für Gruppe in Manifest-Reihenfolge."""
    pending = {}
    target = {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}
    for group, names in want.items():
        placed = {name: (placement_id, item) for placement_id, name, item in current[group]}
        for name in names:
            if name in placed:
                print(f"platzierung {name} schon platziert, übersprungen", flush=True)
                if not good(placed[name][1].get("state")):
                    pending[placed[name][0]] = name
                continue
            relation = {"image": {"data": {"type": "appAssetLibraryImages", "id": images[name]["id"]}}, **target}
            created = client.post(PLACEMENTS, {"placementType": SHOT, "placementGroup": group}, relation)
            pending[created["id"]] = name
            print(f"platzierung {name} angelegt", flush=True)
    return pending


def order_groups(client, loc_id, want, owner):
    """Ein Ordnungsauftrag je Gruppe, nur wenn die gelesene Reihenfolge vom Manifest abweicht."""
    for group, names in want.items():
        rows = read_group(client, loc_id, group, owner)
        found = [name for _, name, _ in rows]
        if found == names or sorted(found) != sorted(names):
            continue
        ids = {name: placement_id for placement_id, name, _ in rows}
        ordered = [{"type": "appAssetLibraryPlacements", "id": ids[name]} for name in names]
        client.post(ORDERING, {"placementGroup": group},
                    {"orderedPlacements": {"data": ordered},
                     "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}})
        print(f"gruppe {group} geordnet", flush=True)


def verify(client, loc_id, want, owner, german_before, locs):
    """Gegenprobe: je Gruppe Namen und Reihenfolge = Manifest; de-DE nur gelesen und unverändert."""
    for group, names in want.items():
        found = [name or placement_id for placement_id, name, _ in read_group(client, loc_id, group, owner)]
        if found != names:
            raise Fatal(f"Gruppe {group}: Soll {', '.join(names)}; Ist {', '.join(found) or 'keine'}")
        print(f"gegenprobe {group} {len(found)} in Manifest-Reihenfolge", flush=True)
    german_after = german_counts(client, locs, want)
    if german_after != german_before:
        raise Fatal(f"de-DE vorher {german_before}, nachher {german_after}")
    print(f"de-DE {german_after or 'fehlt'} unverändert", flush=True)


def platzieren(client, app_id, sprache, versions, lookup, sleep=time.sleep, root=SCREENSHOTS, plattform="ios"):
    """Platzierungen auf en-US: Vorabprüfung nur GET, Anlegen, Warten, Ordnen, Gegenprobe. Löscht nie."""
    entries, _, locs = preflight(client, sprache, versions, lookup, root, plattform)
    warn_mac(versions, plattform)
    loc_id, want = locs[ASC_LOCALES[sprache]]["id"], grouped(entries)
    library_id = client.get(f"/v1/apps/{app_id}/assetLibrary")["id"]
    images = ready_images(client, library_id, [entry["reference"] for entry in entries])
    owner = owners(client, images.values())
    current = {group: read_group(client, loc_id, group, owner) for group in want}
    check_existing(current, want)
    german_before = german_counts(client, locs, want)
    pending = create_missing(client, loc_id, images, want, current)
    wait_placements(client, pending, sleep)
    owner = owners(client, [images[name] for names in want.values() for name in names])
    order_groups(client, loc_id, want, owner)
    verify(client, loc_id, want, owner, german_before, locs)


def print_placements(client, loc_id, entries, owner):
    for group in grouped(entries):
        rows = read_group(client, loc_id, group, owner)
        if not rows:
            print(f"platzierung {group} keine", flush=True)
        for position, (_, name, item) in enumerate(rows, start=1):
            print(f"platzierung {group} {position} {name or '?'} zustand={item.get('state', '?')}", flush=True)


def main(argv):
    plattform = argv[3] if len(argv) == 4 else "ios"
    if len(argv) not in (3, 4) or argv[1] not in ACTIONS or argv[2] not in SPRACHEN or plattform not in PLATTFORMEN:
        print(f"usage: asc_store_images.py {'|'.join(ACTIONS)} {'|'.join(SPRACHEN)} [{'|'.join(PLATTFORMEN)}]",
              file=sys.stderr)
        return 2
    action, sprache = argv[1], argv[2]
    if action == "platzieren" and sprache != "en":
        print(f"::error::platzieren nur für en; sprache={sprache} abgewiesen, de-DE wird nie beschrieben", flush=True)
        return 1
    try:
        config = read_config()
        app_id = find_app_id(config)
        client = Client(config, app_id)
        versions = app_versions(config, app_id)
        lookup = lambda version_id: localizations(config, version_id)  # noqa: E731
        if action == "lesen":
            lesen(client, app_id, sprache, versions, lookup, plattform=plattform)
            return 0
        if action == "platzieren":
            platzieren(client, app_id, sprache, versions, lookup, plattform=plattform)
            return 0
        print(f"zustand {upload(client, app_id, sprache, versions, lookup, plattform=plattform)}", flush=True)
        return 0
    except Fatal as error:
        print(f"::error::{error}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
