"""Erzeugt preview.html: Entwurf des Menüleisten-Symbols (#366) aus derselben Kurve wie ThreadShape."""
import math
import os


def pts(form):
    a = 90.0
    b = 230.0 if form == "knot" else 50.0
    lo, hi = (-3.5, 3.0) if form == "knot" else (-6.8, 6.0)
    out = []
    for i in range(121):
        t = lo + (hi - lo) * i / 120
        out.append((a * t - b * math.sin(t), -b * math.cos(t)))
    return out


def svg(form, h, stroke, color):
    p = pts(form)
    xs = [x for x, _ in p]
    ys = [y for _, y in p]
    w0 = max(xs) - min(xs)
    h0 = max(ys) - min(ys)
    s = (h - stroke) / h0
    w = w0 * s + stroke
    d = " ".join(
        ("M" if i == 0 else "L") + f"{(x - min(xs)) * s + stroke / 2:.2f} {(y - min(ys)) * s + stroke / 2:.2f}"
        for i, (x, y) in enumerate(p)
    )
    return (
        f'<svg width="{w:.1f}" height="{h:.1f}" viewBox="0 0 {w:.2f} {h:.2f}"><path d="{d}" fill="none" '
        f'stroke="{color}" stroke-width="{stroke}" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    )


VARIANTS = [
    ("A", "Knoten, Logo-Strichstärke", "knot", 14, 1.9),
    ("B", "Knoten, kräftiger Strich", "knot", 14, 2.4),
    ("C", "Loser Faden ohne Kreuzung", "loose", 14, 2.0),
]
COLORS = {"light": ("#e9e6ee", "#1c1b22"), "dark": ("#2a2830", "#f2f1f5")}


def bar(mode, glyph):
    bg, fg = COLORS[mode]
    return (
        f'<div class="bar" style="background:{bg};color:{fg}"><span class="m">Loose Ends</span>'
        f'<span class="dim">Ablage</span><span class="sp"></span><span class="dim">WLAN</span>'
        f'<span class="gl">{glyph}</span><span class="dim">Mo 12:41</span></div>'
    )


def heute(mode):
    fg = COLORS[mode][1]
    glyph = (
        f'<svg width="16" height="14" viewBox="0 0 16 14"><g fill="none" stroke="{fg}" stroke-width="1.2" '
        'stroke-linecap="round"><path d="M1.5 2.5h8M1.5 6h8M1.5 9.5h4"/><circle cx="11.5" cy="10" r="3.2"/>'
        '<path d="M11.5 8.4v3.2M9.9 10h3.2"/></g></svg>'
    )
    return bar(mode, glyph)


rows = ""
for key, name, form, h, st in VARIANTS:
    cells = ""
    big = ""
    for mode, label in (("light", "Hell"), ("dark", "Dunkel")):
        bg, fg = COLORS[mode]
        cells += f'<div><div class="lab">{label} · 1×</div>{bar(mode, svg(form, h, st, fg))}</div>'
        big += f'<div class="zoom" style="background:{bg}">{svg(form, h * 6, st * 6, fg)}</div>'
    rows += (
        f'<section><h2><b>{key}</b> {name}</h2>'
        f'<p class="meta">Höhe {h} pt, Strich {st} pt ({st / h * 100:.0f} % der Höhe; Logo: 14 %)</p>'
        f'<div class="pair">{cells}</div><div class="lab">6-fach vergrößert</div><div class="pair">{big}</div></section>'
    )

html = f"""<title>Menüleisten-Faden Entwurf</title>
<style>
:root{{--bg:#f6f5f9;--fg:#1c1b22;--mut:#6b6975;--card:#fff;--line:#dcdae3;--acc:#5b4fd6}}
@media (prefers-color-scheme:dark){{:root:not([data-theme=light]){{--bg:#17161b;--fg:#f2f1f5;--mut:#a09eab;--card:#202026;--line:#34333c;--acc:#9d93ff;color-scheme:dark}}}}
:root[data-theme=dark]{{--bg:#17161b;--fg:#f2f1f5;--mut:#a09eab;--card:#202026;--line:#34333c;--acc:#9d93ff;color-scheme:dark}}
body{{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 -apple-system,system-ui,sans-serif;padding-inline:16px}}
main{{max-width:880px;margin:0 auto;padding-block:24px 48px}}
h1{{font-size:24px;margin:0 0 4px}}h2{{font-size:17px;margin:0}}h2 b{{color:var(--acc)}}
.meta,.lab{{color:var(--mut);font-size:13px;margin:2px 0 8px}}p{{max-width:65ch}}
section{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px;margin-block:16px}}
.pair{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px}}
.bar{{display:flex;align-items:center;gap:14px;height:24px;padding:0 10px;border-radius:6px;font-size:13px;overflow:hidden;white-space:nowrap}}
.sp{{flex:1}}.dim{{opacity:.8}}.m{{font-weight:600}}.gl{{display:flex}}
.zoom{{display:flex;align-items:center;justify-content:center;padding:20px;border-radius:8px}}
</style><main>
<h1>Menüleisten-Symbol: Logo-Faden</h1>
<p>Ticket #366. Das Symbol ist einfarbig (Template): macOS färbt es selbst für Hell, Dunkel und Menüleisten-Tönung. Die Menüleiste ist 24 pt hoch, das Symbol ca. 14 pt. Alle Varianten sind aus derselben Kurve gezeichnet wie das Logo.</p>
<section><h2>Heute</h2><p class="meta">Apple-Symbol <code>text.badge.plus</code>, nachgezeichnet (kein Screenshot)</p><div class="pair">{heute("light")}{heute("dark")}</div></section>
{rows}
<section><h2>Empfehlung</h2><p>Variante A: Sie ist das Logo, nur einfarbig. Ob die Lücke in der Kreuzung bei 1× offen bleibt, zeigt erst der Mac-Prüfbau. B ist dann der Rückfall, ohne dass sich die Form ändert. C ist eine andere Zeichnung und zeigt den Knoten nicht.</p></section>
</main>"""

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "preview.html"), "w", encoding="utf-8") as f:
    f.write(html)
