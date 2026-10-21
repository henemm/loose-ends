"""Kennzahlen der Modell-Latenz je Gruppe (#534, Schnitt 1).

Aufruf: python3 scripts/latency_summary.py <ordner>
Liest alle *.json im Ordner (je Datei eine Liste von Zeilen {gruppe, note, sekunden, fehler?}, geschrieben von
`RealModelLatencyTests` über `sim.sh real-model-latency`) und druckt n, Minimum, Median, p95 und Maximum je Gruppe.
Fehlerproben zählen nur in `fehler`, nie in die Statistik. p95 nach nearest-rank.
"""
import json
import math
import statistics
import sys
from pathlib import Path

GROUPS = ("kalt", "warm")


def p95(values):
    """Nearest-rank: der Wert an Rang ceil(0,95 * n) der sortierten Reihe."""
    ordered = sorted(values)
    rank = max(1, math.ceil(0.95 * len(ordered)))
    return ordered[rank - 1]


def summarize(rows):
    """Gruppe -> {n, min, median, p95, max, fehler}. Eine Gruppe nur mit Fehlerproben hat n = 0 und keine Kennzahlen."""
    out = {}
    for r in rows:
        group = out.setdefault(r["gruppe"], {"werte": [], "fehler": 0})
        if r.get("fehler"):
            group["fehler"] += 1
        else:
            group["werte"].append(float(r["sekunden"]))
    result = {}
    for name, group in out.items():
        values = group["werte"]
        stats = {"n": len(values), "fehler": group["fehler"]}
        if values:
            stats.update(min=min(values), median=statistics.median(values), p95=p95(values), max=max(values))
        result[name] = stats
    return result


def read_folder(folder):
    rows = []
    for path in sorted(Path(folder).glob("*.json")):
        rows.extend(json.loads(path.read_text()))
    return rows


def fmt(value):
    return "-" if value is None else f"{value:.2f}"


def main(argv):
    if len(argv) != 2:
        print("Aufruf: latency_summary.py <ordner>", file=sys.stderr)
        return 2
    folder = Path(argv[1])
    if not folder.is_dir():
        print(f"Kein Ordner: {folder}", file=sys.stderr)
        return 1
    rows = read_folder(folder)
    if not rows:
        print(f"Keine Messzeilen in {folder} (keine *.json oder alle leer).", file=sys.stderr)
        return 1
    out = summarize(rows)
    missing = [g for g in GROUPS if out.get(g, {}).get("n", 0) == 0]
    if missing:
        print(f"Gruppe ohne gültige Probe: {', '.join(missing)} ({folder}).", file=sys.stderr)
        return 1
    print(f"{'Gruppe':<6} {'n':>4} {'min s':>8} {'median s':>9} {'p95 s':>8} {'max s':>8} {'fehler':>7}")
    for name in GROUPS:
        s = out[name]
        print(f"{name:<6} {s['n']:>4} {fmt(s.get('min')):>8} {fmt(s.get('median')):>9} "
              f"{fmt(s.get('p95')):>8} {fmt(s.get('max')):>8} {s['fehler']:>7}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
