"""App-Store-Bilder aus dem Testexport prüfen, benennen und im Manifest verzeichnen (#742, Schnitt 1).

Aufruf (nur aus sim.sh store-screenshots):
  store_screenshots.py <ziel> iphone=<exportordner> ipad=<exportordner>
  store_screenshots.py --watch <ziel> <exportordner>   # Uhr-Bilder nachtragen, Manifest bleibt sonst unberührt
  store_screenshots.py --mac <ziel> <exportordner>     # Mac-Bilder (16:10, eine der Apple-Größen) nachtragen
Ein Exportordner kommt von `xcresulttool export attachments` (mit manifest.json). Nur Standardbibliothek und `sips`.
"""
import json
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORDER = ["01-start", "02-erfassen", "03-neu", "04-detail", "05-erledigt"]
DEVICES = {
    "iphone": {"anzeige": "iPhone 6.3\" (Dynamic Island)", "pixel": (1206, 2622)},
    "ipad": {"anzeige": "iPad 13\"", "pixel": (2064, 2752)},
}
WATCH = {"anzeige": "Apple Watch Series 12/11/10", "pixel": (416, 496), "order": ["01-jetzt", "02-gespeichert"]}
MAC = {"anzeige": "Mac (16:10)", "sizes": [(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)],
       "order": ["01-start", "03-neu", "04-detail", "05-erledigt"]}
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
    want = (DEVICES.get(device) or WATCH)["pixel"] if device != "mac" else None
    sizes_seen = {}
    try:
        for name in order:
            target = staging / f"{name}.png"
            shutil.copyfile(attachments[f"store-{name}"], target)
            strip_alpha(target)
            if device == "ipad":
                clear_grip(target)
            width, height, alpha = info(target)
            if device == "mac":
                if (width, height) not in MAC["sizes"]:
                    raise StoreError(f"mac/{target.name}: {size_text((width, height))} ist keine Mac-Größe von Apple")
                if sizes_seen.setdefault("mac", (width, height)) != (width, height):
                    raise StoreError(f"mac/{target.name}: Größe weicht von den anderen Bildern ab")
            elif (width, height) != want:
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


def png_flatten_alpha(path):
    """RGBA-PNG (8 Bit, ohne Zeilensprung) → RGB-PNG, Transparenz auf Weiß gerechnet; die Fensterecken des Mac sind rund."""
    data = Path(path).read_bytes()
    pos, chunks, header = 8, [], None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            chunks.append(body)
    width, height, depth, color, _, _, interlace = header
    if (depth, color, interlace) != (8, 6, 0):
        raise StoreError(f"{path}: nur RGBA mit 8 Bit ohne Zeilensprung, nicht {depth}/{color}/{interlace}")
    raw, stride = zlib.decompress(b"".join(chunks)), width * 4
    rows, prev = [], bytearray(stride)
    for y in range(height):
        filt, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b, c = prev[i], (prev[i - 4] if i >= 4 else 0)
            if filt == 1:
                line[i] = (line[i] + a) & 255
            elif filt == 2:
                line[i] = (line[i] + b) & 255
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif filt == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    out = bytearray()
    for line in rows:
        out.append(0)
        for x in range(0, stride, 4):
            alpha = line[x + 3]
            out += bytes((v * alpha + 255 * (255 - alpha)) // 255 for v in line[x:x + 3])

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(bytes(out), 9)) + chunk(b"IEND", b""))


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


def main_mac(out_root, export):
    """Trägt die Mac-Bilder in Ordner und Manifest nach; die übrigen Einträge bleiben stehen."""
    out_root = Path(out_root)
    written = finish_device("mac", read_export(export), out_root, sips_info, png_flatten_alpha, order=MAC["order"])
    width, height, _ = sips_info(written[0])
    manifest_path = out_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["geraete"] = [g for g in manifest["geraete"] if g["geraet"] != "mac"] + [
        {"geraet": "mac", "anzeige": MAC["anzeige"], "pixel": size_text((width, height)), "ordner": "mac",
         "dateien": [path.name for path in written]}]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"[store] {len(written)} Mac-Bilder ({size_text((width, height))}) in {out_root / 'mac'}")


def main(argv):
    if argv[0] == "--mac":
        return main_mac(argv[1], argv[2])
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
