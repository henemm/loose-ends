"""Zeichnet das Kopfbild für den App Store (#772, Variante C): Faden, Name und Slogan links, Startseite rechts.

Aufruf: store_header.py [zielordner]   (Standard: docs/store/header/)
Schreibt {hell,dunkel}-{16x9,21x9}.png (RGB, ohne Alpha) und manifest.json. Byte-gleich bei jedem Lauf:
keine Zeit, keine Metadaten, feste PNG-Parameter. Braucht Pillow und eine Systemschrift aus FONTS (macOS).
"""
import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SCREEN = ROOT / "docs/store/screenshots/de/iphone/01-start.png"
OUT = ROOT / "docs/store/header"
SIZES = {"16x9": (5244, 2950), "21x9": (3840, 1646)}
PAPER = (0xF4, 0xF3, 0xEE)
VARIANTS = {"hell": {"surface": (0x0F, 0x6E, 0x73), "thread": PAPER},
            "dunkel": {"surface": (0x10, 0x18, 0x19), "thread": (0x5F, 0xC4, 0xC9)}}
SLOGAN = "Sag es, und es ist sortiert."
FONTS = [("/System/Library/Fonts/HelveticaNeue.ttc", 1, 0), ("/System/Library/Fonts/Helvetica.ttc", 1, 0)]
# Je Format eine eigene Anordnung, Anteile an der Höhe des Innenfelds (Rand 14 %, geprüft werden 12 %).
LAYOUT = {"16x9": {"inset": 0.14, "logo": 0.34, "title": 0.13, "slogan": 0.062, "phone": 0.96},
          "21x9": {"inset": 0.14, "logo": 0.36, "title": 0.165, "slogan": 0.075, "phone": 1.0}}
SUPER = 4  # Überabtastung des Fadens für glatte Kanten; der Kern bleibt exakt die Fadenfarbe
TILT = 6   # Grad, gegen den Uhrzeigersinn wie im Entwurf


def font(size, bold):
    for path, bold_index, regular_index in FONTS:
        if Path(path).exists():
            return ImageFont.truetype(path, size, index=bold_index if bold else regular_index)
    raise SystemExit(f"Keine Schrift gefunden, erwartet eine von: {', '.join(p for p, _, _ in FONTS)}")


def trochoid(t0, t1, n):
    a, b = 90, 230
    return [(a * t - b * math.sin(t), -b * math.cos(t)) for t in (t0 + (t1 - t0) * i / n for i in range(n + 1))]


def thread_mask(height):
    """Faden wie docs/design/logo/generate.py.txt: Kurve, Lücke an der Kreuzung, oberes Stück darüber."""
    t = 2.0
    for _ in range(60):
        t -= (90 * t - 230 * math.sin(t)) / (90 - 230 * math.cos(t))
    curve, over = trochoid(-3.5, 3.0, 400), trochoid(t - 0.55, t + 0.55, 60)
    xs, ys = [p[0] for p in curve], [p[1] for p in curve]
    left, top = min(xs) - 36, min(ys) - 36
    scale = height * SUPER / (max(ys) + 36 - top)
    size = (round((max(xs) + 36 - left) * scale), height * SUPER)
    place = lambda pts: [((x - left) * scale, (y - top) * scale) for x, y in pts]  # noqa: E731
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)

    def stroke(pts):
        # Einzelstücke plus Kreis an jedem Punkt: ein dicker Polygonzug lässt sonst feine Schlitze zwischen den Stücken
        draw.line(pts, fill=255, width=round(72 * scale))
        r = 36 * scale
        for x, y in pts:
            draw.ellipse((x - r, y - r, x + r, y + r), fill=255)

    def gap(pts):
        # Lücke mit geraden Enden als ein Band: Normale je Punkt, ±75 Einheiten
        half, sides = 75 * scale, ([], [])
        for i, (x, y) in enumerate(pts):
            (ax, ay), (bx, by) = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
            length = math.hypot(bx - ax, by - ay)
            nx, ny = -(by - ay) / length * half, (bx - ax) / length * half
            sides[0].append((x + nx, y + ny))
            sides[1].append((x - nx, y - ny))
        draw.polygon(sides[0] + sides[1][::-1], fill=0)

    stroke(place(curve))
    gap(place(over))
    stroke(place(over))
    return mask.resize((round(size[0] / SUPER), height), Image.Resampling.BOX)


def phone(height):
    """Startseite in dunklem, abgerundetem Rahmen, gekippt; dazu ihr Schatten. Beide RGBA."""
    shot = Image.open(SCREEN).convert("RGB")
    bezel = round(height * 0.022)
    inner_h = height - 2 * bezel
    inner = shot.resize((round(inner_h * shot.width / shot.height), inner_h), Image.Resampling.LANCZOS)
    body = Image.new("RGBA", (inner.width + 2 * bezel, height), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, height - 1), radius=round(height * 0.06),
                                           fill=(0x17, 0x18, 0x16, 255))
    screen_mask = Image.new("L", inner.size, 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, inner.width - 1, inner_h - 1),
                                                  radius=round(height * 0.045), fill=255)
    body.paste(inner, (bezel, bezel), screen_mask)
    body = body.rotate(TILT, resample=Image.Resampling.BICUBIC, expand=True)
    pad = round(height * 0.04)
    shade = Image.new("L", (body.width + 2 * pad, body.height + 2 * pad), 0)
    shade.paste(body.getchannel("A").point(lambda v: v * 30 // 100), (pad, pad))
    return body, shade.filter(ImageFilter.GaussianBlur(height * 0.012)), pad


def draw(variant, size):
    colors, (width, height) = VARIANTS[variant], SIZES[size]
    spec = LAYOUT[size]
    image = Image.new("RGB", (width, height), colors["surface"])
    x0, y0 = round(width * spec["inset"]), round(height * spec["inset"])
    x1, y1 = width - x0, height - y0
    box_h = y1 - y0

    # rechts: App-Ansicht; Schatten versetzt, alles innerhalb des Innenfelds
    offset = round(box_h * 0.02)
    body, shade, pad = phone(round(box_h * spec["phone"] / (math.cos(math.radians(TILT)) + 0.5 * math.sin(math.radians(TILT)))))
    blur = round(box_h * 0.04)
    if body.height + offset + blur > box_h:
        scale = (box_h - offset - blur) / body.height
        body, shade, pad = phone(round(body.height * scale * 0.95))
    px = x1 - body.width - offset - blur
    py = y0 + (box_h - body.height - offset) // 2
    sx, sy = px + offset - pad, py + offset - pad
    image.paste((0, 0, 0), (sx, sy, sx + shade.width, sy + shade.height), shade)
    image.paste(body, (px, py), body)

    # links: Faden, Name, Slogan, untereinander, im freien Feld mittig
    mask = thread_mask(round(box_h * spec["logo"]))
    title, slogan = font(round(box_h * spec["title"]), True), font(round(box_h * spec["slogan"]), False)
    t_box, s_box = title.getbbox("Loose Ends"), slogan.getbbox(SLOGAN)
    gap = round(box_h * 0.05)
    block_w = max(mask.width, t_box[2], s_box[2])
    block_h = mask.height + gap + (t_box[3] - t_box[1]) + gap // 2 + (s_box[3] - s_box[1])
    free = px - x0 - blur
    if block_w > free:
        raise ValueError(f"{variant}-{size}: Textblock {block_w} px breiter als das freie Feld {free} px")
    bx, by = x0 + (free - block_w) // 2, y0 + (box_h - block_h) // 2
    image.paste(colors["thread"], (bx, by, bx + mask.width, by + mask.height), mask)
    ink = ImageDraw.Draw(image)
    ty = by + mask.height + gap - t_box[1]
    ink.text((bx - t_box[0], ty), "Loose Ends", font=title, fill=PAPER)
    sy = ty + t_box[3] + gap // 2 - s_box[1]
    soft = tuple(round(p * 0.85 + s * 0.15) for p, s in zip(PAPER, colors["surface"]))
    ink.text((bx - s_box[0], sy), SLOGAN, font=slogan, fill=soft)
    return image


def build(out_dir=OUT):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for variant in VARIANTS:
        for size, (width, height) in SIZES.items():
            name = f"{variant}-{size}.png"
            draw(variant, size).save(out_dir / name, format="PNG", optimize=False, compress_level=9)
            digest = hashlib.sha256((out_dir / name).read_bytes()).hexdigest()
            files.append({"file": name, "width": width, "height": height, "sha256": digest})
    (out_dir / "manifest.json").write_text(json.dumps({"files": files}, indent=2) + "\n")
    return files


if __name__ == "__main__":
    for entry in build(sys.argv[1] if len(sys.argv) > 1 else OUT):
        print(f"{entry['file']} {entry['width']}x{entry['height']} {entry['sha256']}", flush=True)
