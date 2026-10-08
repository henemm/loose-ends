#!/usr/bin/env python3
"""Vergleicht zwei Messberichte (docs/reference/*.md) Feld für Feld (#73).

Die Berichte sind Markdown mit Tabellen, deren Zellen Prozentwerte tragen ("49.6 % von 139"). Das
Werkzeug liest jede solche Zelle als Messwert mit dem Schlüssel

    Abschnitt  ›  Zeilenbeschriftung  ›  Spaltenüberschrift

und legt zwei Berichte nebeneinander: alter Wert, neuer Wert, Differenz in Prozentpunkten. Fällt oder
steigt ein Wert um mehr als die Schwelle (Vorgabe 10 Punkte, Annahme B5), steht er in der Liste der
Ausreißer, und das Programm endet mit Exit-Code 1. Dann gilt: Das Feld wird bis zur Klärung nicht
mehr still gesetzt.

Richtung: Bei Werten, die Fehler zählen ("erfunden", "falsch", "verpasst", "Fehler"), ist ein Anstieg
die Verschlechterung, sonst der Abfall. Das Werkzeug urteilt nur darüber, welche Richtung schlechter
ist, nicht darüber, ob die Messung stimmt.

    python3 scripts/compare_reports.py alt.md neu.md [--threshold 10]
"""
import argparse
import re
import sys
from pathlib import Path

PERCENT = re.compile(r"(-?\d+(?:[.,]\d+)?)\s*%")
BAD_WORDS = ("erfunden", "falsch", "verpasst", "fehler", "fehlversuche", "drossel", "invented", "wrong", "missed")
SEPARATOR_ROW = re.compile(r"^\s*\|?[\s:\-|]+\|?\s*$")


class ReportError(Exception):
    pass


def cells(line):
    """Die Zellen einer Markdown-Tabellenzeile, ohne die äußeren Striche."""
    parts = line.strip().strip("|").split("|")
    return [part.strip() for part in parts]


def parse(text):
    """Alle Prozentzellen eines Berichts: {Schlüssel: Wert}. Gleiche Schlüssel werden durchnummeriert."""
    values = {}
    heading = ""
    header = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            header = None
            continue
        if not stripped.startswith("|"):
            header = None
            continue
        if SEPARATOR_ROW.match(stripped):
            continue
        row = cells(stripped)
        if header is None:
            header = row
            continue
        label = row[0] if row else ""
        for index, cell in enumerate(row[1:], start=1):
            match = PERCENT.search(cell)
            if not match:
                continue
            column = header[index] if index < len(header) else f"Spalte {index}"
            key = f"{heading} › {label} › {column}"
            if key in values:
                n = 2
                while f"{key} ({n})" in values:
                    n += 1
                key = f"{key} ({n})"
            values[key] = float(match.group(1).replace(",", "."))
    return values


def is_error_metric(key):
    lowered = key.lower()
    return any(word in lowered for word in BAD_WORDS)


def compare(old, new, threshold):
    """Liefert (Zeilen, Ausreißer, nur_alt, nur_neu). Zeile: (Schlüssel, alt, neu, Differenz, schlechter)."""
    rows = []
    outliers = []
    for key in old:
        if key not in new:
            continue
        delta = round(new[key] - old[key], 1)
        worse = delta > 0 if is_error_metric(key) else delta < 0
        row = (key, old[key], new[key], delta, worse and delta != 0)
        rows.append(row)
        if abs(delta) > threshold:
            outliers.append(row)
    only_old = [key for key in old if key not in new]
    only_new = [key for key in new if key not in old]
    return rows, outliers, only_old, only_new


def render(rows, outliers, only_old, only_new, threshold):
    out = ["| Messwert | alt | neu | Differenz (Punkte) | |", "|---|---|---|---|---|"]
    for key, a, b, delta, worse in rows:
        flag = ""
        if abs(delta) > threshold:
            flag = "schlechter, Ausreißer" if worse else "besser, Ausreißer"
        elif delta != 0:
            flag = "schlechter" if worse else "besser"
        out.append(f"| {key} | {a:.1f} % | {b:.1f} % | {delta:+.1f} | {flag} |")
    out.append("")
    out.append(f"Verglichen: {len(rows)} Messwerte; Schwelle {threshold:g} Punkte; Ausreißer: {len(outliers)}, "
               f"davon schlechter: {sum(1 for row in outliers if row[4])}.")
    if only_old:
        out.append(f"Nur im alten Bericht: {len(only_old)} Messwerte.")
    if only_new:
        out.append(f"Nur im neuen Bericht: {len(only_new)} Messwerte.")
    return "\n".join(out)


def load(path):
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise ReportError(f"{path}: {error.strerror}") from error
    values = parse(text)
    if not values:
        raise ReportError(f"{path}: keine Prozentwerte in Tabellen gefunden")
    return values


def main(argv=None):
    parser = argparse.ArgumentParser(description="Zwei Messberichte vergleichen (#73)")
    parser.add_argument("alt")
    parser.add_argument("neu")
    parser.add_argument("--threshold", type=float, default=10.0, help="Punkte, ab denen ein Wert Ausreißer ist")
    args = parser.parse_args(argv)
    try:
        old, new = load(args.alt), load(args.neu)
    except ReportError as error:
        print(f"Fehler: {error}", file=sys.stderr)
        return 2
    rows, outliers, only_old, only_new = compare(old, new, args.threshold)
    if not rows:
        print("Fehler: die beiden Berichte haben keinen gemeinsamen Messwert", file=sys.stderr)
        return 2
    print(render(rows, outliers, only_old, only_new, args.threshold))
    return 1 if outliers else 0


if __name__ == "__main__":
    sys.exit(main())
