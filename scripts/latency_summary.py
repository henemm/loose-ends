"""Kennzahlen der Modell-Latenz je Gruppe (#534, Schnitte 1 und 2).

Aufruf: python3 scripts/latency_summary.py <ordner>
Liest alle *.json im Ordner in einem von zwei Formaten:
- Mac (Schnitt 1): je Datei eine Liste von Zeilen {gruppe, note, sekunden, fehler?}, geschrieben von
  `RealModelLatencyTests` über `sim.sh real-model-latency`.
- Labor-App (Schnitt 2): je Datei ein Start {name, results[], events[]} von `sim.sh lab-latency`; der erste Eintrag
  ist kalt, die übrigen warm, `error` zählt als Fehler, `conditions` trägt Hitze und Stromquelle.
Druckt n, Minimum, Median, p95 und Maximum je Gruppe, im Labor-Format zusätzlich das Maximum je Hitzestufe und die
Aufrufe je Stromquelle. Fehlerproben zählen nur in `fehler`, nie in die Statistik. p95 nach nearest-rank.
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
        group = out.setdefault(r["gruppe"], {"werte": [], "fehler": 0, "hitze": {}, "strom": {}})
        if r.get("fehler"):
            group["fehler"] += 1
            continue
        value = float(r["sekunden"])
        group["werte"].append(value)
        if "hitze" in r:
            group["hitze"][r["hitze"]] = max(value, group["hitze"].get(r["hitze"], value))
        if "strom" in r:
            group["strom"][r["strom"]] = group["strom"].get(r["strom"], 0) + 1
    result = {}
    for name, group in out.items():
        values = group["werte"]
        stats = {"n": len(values), "fehler": group["fehler"]}
        if values:
            stats.update(min=min(values), median=statistics.median(values), p95=p95(values), max=max(values))
        if group["hitze"] or group["strom"]:
            stats.update(max_by_thermal=group["hitze"], power=group["strom"])
        result[name] = stats
    return result


def lab_rows(run):
    """Ein Start der Labor-App als Zeilen: der erste Eintrag ist kalt, die übrigen warm."""
    rows = []
    for index, result in enumerate(run.get("results", [])):
        conditions = result.get("conditions", {})
        rows.append({"gruppe": "kalt" if index == 0 else "warm", "note": result.get("entryID", ""),
                     "sekunden": result["seconds"], "fehler": result.get("error"),
                     "hitze": conditions.get("thermal", "unbekannt"), "strom": conditions.get("power", "unbekannt")})
    return rows


def read_folder(folder):
    rows = []
    for path in sorted(Path(folder).glob("*.json")):
        data = json.loads(path.read_text())
        rows.extend(lab_rows(data) if isinstance(data, dict) else data)
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
    for name in GROUPS:
        s = out[name]
        if "max_by_thermal" in s:
            thermal = ", ".join(f"{k} {fmt(v)} s" for k, v in sorted(s["max_by_thermal"].items()))
            power = ", ".join(f"{k} {v}" for k, v in sorted(s["power"].items()))
            print(f"{name}: Maximum je Hitze: {thermal}; Aufrufe je Strom: {power}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
