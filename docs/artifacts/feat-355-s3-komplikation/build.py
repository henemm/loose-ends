"""Erzeugt preview.html: Entwurf der Watch-Komplikation (#355 Schnitt 3) aus derselben Kurve wie ThreadShape."""
import base64
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ACCENT_LIGHT = "#0F6E73"  # AccentColor.colorset, hell
ACCENT_DARK = "#5FC4C9"  # AccentColor.colorset, dunkel (auf dem Zifferblatt)


def knot_path(size, stroke, ox=0.0, oy=0.0):
    a, b = 90.0, 230.0
    p = []
    for i in range(121):
        t = -3.5 + 6.5 * i / 120
        p.append((a * t - b * math.sin(t), -b * math.cos(t)))
    xs = [x for x, _ in p]
    ys = [y for _, y in p]
    s = (size - stroke) / max(max(xs) - min(xs), max(ys) - min(ys))
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    d = " ".join(
        ("M" if i == 0 else "L") + f"{(x - cx) * s + ox:.2f} {(y - cy) * s + oy:.2f}" for i, (x, y) in enumerate(p)
    )
    return (
        f'<path d="{d}" fill="none" stroke="{ACCENT_DARK}" stroke-width="{stroke}" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
    )


def mic(ox, oy):
    return (
        f'<g fill="none" stroke="{ACCENT_DARK}" stroke-width="2.6" stroke-linecap="round">'
        f'<rect x="{ox - 5}" y="{oy - 13}" width="10" height="17" rx="5"/>'
        f'<path d="M{ox - 10} {oy - 1} a10 10 0 0 0 20 0"/><path d="M{ox} {oy + 9} v5"/></g>'
    )


def shortcuts(ox, oy):
    return (
        f'<g fill="none" stroke="#c9c4d6" stroke-width="2.4" stroke-linejoin="round">'
        f'<rect x="{ox - 11}" y="{oy - 11}" width="15" height="15" rx="4" transform="rotate(45 {ox - 3.5} {oy - 3.5})"/>'
        f'<rect x="{ox - 4}" y="{oy - 4}" width="15" height="15" rx="4" transform="rotate(45 {ox + 3.5} {oy + 3.5})"/></g>'
    )


def face(circ_glyph, corner_glyph, corner_label):
    """Ein Zifferblatt (Modular-ähnlich) mit Eckkomplikation oben links und runder Komplikation unten."""
    corner = ""
    if corner_glyph:
        corner = (
            f"{corner_glyph}"
            f'<path id="arc" d="M14 80 A118 118 0 0 1 80 14" fill="none"/>'
            f'<text font-size="11" font-weight="600" letter-spacing="1.2" fill="{ACCENT_DARK}">'
            f'<textPath href="#arc" startOffset="58%">{corner_label}</textPath></text>'
        )
    return (
        '<svg class="watch" viewBox="0 0 208 248" role="img" aria-label="Zifferblatt">'
        '<rect x="0" y="0" width="208" height="248" rx="44" fill="#000"/>'
        f"{corner}"
        '<text x="194" y="40" text-anchor="end" font-size="22" font-weight="600" fill="#fff">23:15</text>'
        '<text x="104" y="128" text-anchor="middle" font-size="56" font-weight="700" fill="#fff" '
        'font-variant-numeric="tabular-nums">23:15</text>'
        '<text x="104" y="152" text-anchor="middle" font-size="13" fill="#9a97a3">DI 13. OKT.</text>'
        f'<circle cx="62" cy="200" r="25" fill="#1f1e24"/>{circ_glyph}'
        '<circle cx="146" cy="200" r="25" fill="#1f1e24"/>'
        '<path d="M133 205 a14 14 0 0 1 26 0" fill="none" stroke="#e3584e" stroke-width="4" stroke-linecap="round"/>'
        '<text x="146" y="214" text-anchor="middle" font-size="10" fill="#c9c4d6">72</text>'
        "</svg>"
    )


def img(name):
    with open(os.path.join(HERE, name), "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


ENTWURF = face(knot_path(30, 3.2, 62, 200), knot_path(26, 3.0, 36, 38), "ERFASSEN")
ALT_B = face(mic(62, 202), mic(34, 40), "ERFASSEN")
ALT_C = face(shortcuts(62, 200), "", "")

OLD_DE = ("Sag zu Siri „In Loose Ends erfassen“. Oder leg im Kontrollzentrum das Kurzbefehle-Steuerelement mit "
          "„Aufgabe erfassen“ ab. Beides speichert, ohne die App zu öffnen.")
NEW_DE = ("Sag zu Siri „Erfasse in Loose Ends“. Oder leg im Kontrollzentrum das Kurzbefehle-Steuerelement mit "
          "„Aufgabe erfassen“ ab. Beides speichert, ohne die App zu öffnen. Auf der Apple Watch führt der Knoten "
          "auf dem Zifferblatt direkt zur Erfassung.")

html = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()
for key, value in {
    "{{HEUTE_FACE}}": img("heute-zifferblatt.png"),
    "{{HEUTE_CAPTURE}}": img("heute-erfassung.png"),
    "{{ENTWURF}}": ENTWURF,
    "{{ALT_B}}": ALT_B,
    "{{ALT_C}}": ALT_C,
    "{{OLD_DE}}": OLD_DE,
    "{{NEW_DE}}": NEW_DE,
}.items():
    html = html.replace(key, value)
with open(os.path.join(HERE, "preview.html"), "w", encoding="utf-8") as f:
    f.write(html)
print("preview.html geschrieben")
