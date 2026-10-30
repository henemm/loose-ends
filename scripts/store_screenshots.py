"""App-Store-Bilder aus dem Testexport prüfen, benennen und im Manifest verzeichnen (#742, Schnitt 1).

Aufruf (nur aus sim.sh store-screenshots):
  store_screenshots.py <ziel> iphone=<exportordner> ipad=<exportordner>
Ein Exportordner kommt von `xcresulttool export attachments` (mit manifest.json). Nur Standardbibliothek und `sips`.
"""
import json
import shutil
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


def finish_device(device, attachments, out_root, info, strip_alpha):
    """Schreibt die fünf Bilder eines Geräts nach <out_root>/<gerät>/<nn>-<name>.png und prüft sie.

    attachments: Anhangsname `store-<nn>-<name>` → Datei; info(path) → (breite, höhe, alpha); strip_alpha(path).
    """
    missing = [name for name in ORDER if f"store-{name}" not in attachments]
    if missing:
        raise StoreError(f"{device}: Bild fehlt: {', '.join(missing)}")
    folder = Path(out_root) / device
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    want = DEVICES[device]["pixel"]
    written = []
    for name in ORDER:
        target = folder / f"{name}.png"
        shutil.copyfile(attachments[f"store-{name}"], target)
        strip_alpha(target)
        width, height, alpha = info(target)
        if (width, height) != want:
            raise StoreError(f"{device}/{target.name}: {size_text((width, height))} statt {size_text(want)}")
        if alpha:
            raise StoreError(f"{device}/{target.name}: Alphakanal nicht entfernt")
        written.append(target)
    return written


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


def read_export(folder):
    """Anhänge `store-*` aus einem xcresulttool-Export: Name ohne Zusatz `_<n>_<uuid>` → Datei."""
    folder = Path(folder)
    found = {}
    for test in json.loads((folder / "manifest.json").read_text()):
        for item in test.get("attachments", []):
            stem = item.get("suggestedHumanReadableName", "").split("_")[0]
            if stem.startswith("store-"):
                found[stem] = folder / item["exportedFileName"]
    return found


def main(argv):
    out_root, exports = Path(argv[0]), dict(arg.split("=", 1) for arg in argv[1:])
    names = {}
    for device in DEVICES:
        if device not in exports:
            raise StoreError(f"Kein Export für {device}")
        written = finish_device(device, read_export(exports[device]), out_root, sips_info, sips_strip_alpha)
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
