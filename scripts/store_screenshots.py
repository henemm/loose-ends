"""App-Store-Bilder aus dem Testexport prüfen, benennen und im Manifest verzeichnen (#742, Schnitt 1).

Aufruf (nur aus sim.sh store-screenshots):
  store_screenshots.py <ziel> iphone=<exportordner> ipad=<exportordner>
  store_screenshots.py --watch <ziel> <exportordner>   # Uhr-Bilder nachtragen, Manifest bleibt sonst unberührt
Ein Exportordner kommt von `xcresulttool export attachments` (mit manifest.json). Nur Standardbibliothek und `sips`.
"""
import json
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORDER = ["01-start", "02-erfassen", "03-neu", "04-detail", "05-erledigt"]
DEVICES = {
    "iphone": {"anzeige": "iPhone 6.3\" (Dynamic Island)", "pixel": (1206, 2622)},
    "ipad": {"anzeige": "iPad 13\"", "pixel": (2064, 2752)},
}
WATCH = {"anzeige": "Apple Watch Series 12/11/10", "pixel": (416, 496), "order": ["01-jetzt", "02-gespeichert"]}
README = """# App-Store-Bilder (Deutsch)

Für App Store Connect, Sprache Deutsch (de-DE): Die Bilder in `iphone/` gehören zur Größe „iPhone 6.3\" Display“
(1206×2622), die in `ipad/` zu „iPad 13\" Display“ (2064×2752); `manifest.json` nennt je Größe Pixelmaß und Dateien.
Hochladen in der Reihenfolge der Dateinamen (01 zuerst), ohne Bildunterzeilen und ohne Rahmen.

Erzeugt mit `./scripts/sim.sh store-screenshots` (#742), nie von Hand.
"""


class StoreError(Exception):
    pass


def size_text(size):
    return f"{size[0]}x{size[1]}"


def finish_device(device, attachments, out_root, info, strip_alpha, clear_grip=lambda path: None, order=None):
    """Schreibt die fünf Bilder eines Geräts nach <out_root>/<gerät>/<nn>-<name>.png und prüft sie.

    attachments: Anhangsname `store-<nn>-<name>` → Datei; info(path) → (breite, höhe, alpha); strip_alpha(path);
    clear_grip(path) nur auf dem iPad (Fenstergriff unten rechts).
    """
    order = order or ORDER
    missing = [name for name in order if f"store-{name}" not in attachments]
    if missing:
        raise StoreError(f"{device}: Bild fehlt: {', '.join(missing)}")
    folder = Path(out_root) / device
    # Erst prüfen, dann ersetzen (F001): ein Fehler lässt den bisherigen Geräteordner unberührt.
    staging = Path(out_root) / f".{device}-neu"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    want = (DEVICES.get(device) or WATCH)["pixel"]
    try:
        for name in order:
            target = staging / f"{name}.png"
            shutil.copyfile(attachments[f"store-{name}"], target)
            strip_alpha(target)
            if device == "ipad":
                clear_grip(target)
            width, height, alpha = info(target)
            if (width, height) != want:
                raise StoreError(f"{device}/{target.name}: {size_text((width, height))} statt {size_text(want)}")
            if alpha:
                raise StoreError(f"{device}/{target.name}: Alphakanal nicht entfernt")
    except BaseException:
        shutil.rmtree(staging)
        raise
    if folder.exists():
        shutil.rmtree(folder)
    staging.rename(folder)
    return [folder / f"{name}.png" for name in order]


def build_manifest(names_by_device, commit, created):
    missing = [device for device in DEVICES if device not in names_by_device]
    if missing:
        raise StoreError(f"Manifest unvollständig, es fehlt: {', '.join(missing)}")
    return {
        "sprache": "de-DE",
        "erzeugt": created,
        "commit": commit,
        "geraete": [
            {"geraet": device, "anzeige": spec["anzeige"], "pixel": size_text(spec["pixel"]), "ordner": device,
             "dateien": [f"{name}.png" for name in names_by_device[device]]}
            for device, spec in DEVICES.items()
        ],
    }


def sips_info(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
                         capture_output=True, text=True, check=True).stdout
    values = dict(line.strip().split(": ", 1) for line in out.splitlines()[1:] if ": " in line)
    return int(values["pixelWidth"]), int(values["pixelHeight"]), values["hasAlpha"].strip() == "yes"


def sips_strip_alpha(path):
    """PNG → BMP → PNG: verlustfrei, ohne Alphakanal."""
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "bild.bmp"
        subprocess.run(["sips", "-s", "format", "bmp", str(path), "--out", str(bmp)], capture_output=True, check=True)
        subprocess.run(["sips", "-s", "format", "png", str(bmp), "--out", str(path)], capture_output=True, check=True)


GRIP_CORNER = 72      # Kante des Eckquadrats unten rechts in Pixeln; der Griff liegt bei x 2008–2054, y 2696–2742
GRIP_BAND = 8         # Breite des Streifens links und über der Ecke, aus dem die Hintergrundfarbe kommt
GRIP_TOLERANCE = 2    # größte Abweichung je Farbkanal, die im Streifen noch als einfarbig gilt


def clear_grip_bmp(data):
    """Färbt die Ecke unten rechts in die Farbe ihrer Umgebung, wenn die Umgebung einfarbig ist; sonst unverändert.

    data: BMP mit 24 oder 32 Bit je Pixel (Ausgabe von `sips`). Gibt das neue BMP zurück.
    """
    offset, = struct.unpack_from("<I", data, 10)
    width, height, _, bits = struct.unpack_from("<iiHH", data, 18)
    step, stride, rows = bits // 8, (width * bits // 8 + 3) // 4 * 4, abs(height)

    def index(x, y):   # y von oben gezählt; BMP liegt mit positiver Höhe von unten nach oben
        return offset + (y if height < 0 else rows - 1 - y) * stride + x * step

    left, top = width - GRIP_CORNER, rows - GRIP_CORNER
    band = [(x, y) for y in range(top - GRIP_BAND, rows) for x in range(left - GRIP_BAND, left)]
    band += [(x, y) for y in range(top - GRIP_BAND, top) for x in range(left, width)]
    colors = [data[index(x, y):index(x, y) + 3] for x, y in band]
    if any(max(abs(a - b) for a, b in zip(color, colors[0])) > GRIP_TOLERANCE for color in colors):
        return data
    out = bytearray(data)
    for y in range(top, rows):
        for x in range(left, width):
            out[index(x, y):index(x, y) + 3] = colors[0]
    return bytes(out)


def sips_clear_grip(path):
    """PNG → BMP → Griff entfernen → PNG, verlustfrei und ohne Alphakanal (#742)."""
    with tempfile.TemporaryDirectory() as tmp:
        bmp = Path(tmp) / "bild.bmp"
        subprocess.run(["sips", "-s", "format", "bmp", str(path), "--out", str(bmp)], capture_output=True, check=True)
        bmp.write_bytes(clear_grip_bmp(bmp.read_bytes()))
        subprocess.run(["sips", "-s", "format", "png", str(bmp), "--out", str(path)], capture_output=True, check=True)


def read_export(folder):
    """Anhänge `store-*` aus einem xcresulttool-Export: Name ohne Zusatz `_<n>_<uuid>` → Datei."""
    folder = Path(folder)
    found = {}
    for test in json.loads((folder / "manifest.json").read_text()):
        for item in test.get("attachments", []):
            stem = item.get("suggestedHumanReadableName", "").split("_")[0]
            if stem.startswith("store-"):
                if stem in found:   # F002: zwei Anhänge gleichen Namens, keiner ist eindeutig der richtige
                    raise StoreError(f"Anhang doppelt: {stem}")
                found[stem] = folder / item["exportedFileName"]
    return found


def main_watch(out_root, export):
    """Trägt die Uhr-Bilder in Ordner und Manifest nach; die übrigen Einträge bleiben stehen."""
    out_root = Path(out_root)
    written = finish_device("watch", read_export(export), out_root, sips_info, sips_strip_alpha, order=WATCH["order"])
    manifest_path = out_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["geraete"] = [g for g in manifest["geraete"] if g["geraet"] != "watch"] + [
        {"geraet": "watch", "anzeige": WATCH["anzeige"], "pixel": size_text(WATCH["pixel"]), "ordner": "watch",
         "dateien": [path.name for path in written]}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"[store] {len(written)} Uhr-Bilder in {out_root / 'watch'}")


def main(argv):
    if argv[0] == "--watch":
        return main_watch(argv[1], argv[2])
    out_root, exports = Path(argv[0]), dict(arg.split("=", 1) for arg in argv[1:])
    names = {}
    for device in DEVICES:
        if device not in exports:
            raise StoreError(f"Kein Export für {device}")
        written = finish_device(device, read_export(exports[device]), out_root, sips_info, sips_strip_alpha,
                                sips_clear_grip)
        names[device] = [path.stem for path in written]
    commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True,
                            check=True).stdout.strip()
    manifest = build_manifest(names, commit, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    (out_root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (out_root / "README.md").write_text(README)
    print(f"[store] {sum(len(v) for v in names.values())} Bilder und manifest.json in {out_root}")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except StoreError as problem:
        print(f"[store] {problem}", file=sys.stderr)
        sys.exit(1)
