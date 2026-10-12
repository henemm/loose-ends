#!/usr/bin/env python3
"""Welche Messstrecken sind gelaufen, welche mangels Daten übersprungen? (#135, #149)

Die Mess-Suiten hängen an persönlichen, gitignorierten Dateien. Fehlen sie, überspringt Swift
Testing die Suite, und der Lauf meldet trotzdem „Test Succeeded“. Dieses Skript sagt es laut:
`sim.sh unit` ruft es nach jedem Lauf, die CI schreibt es mit `--markdown` in die Zusammenfassung.

Die Suche spiegelt `LooseEndsTests/MeasurementData.swift`: erst `docs/reference/` des eigenen
Arbeitsstands, dann die des Hauptordners, wenn der Arbeitsstand unter `.claude/worktrees/<name>`
liegt. Welche Suite an welcher Datei hängt, steht in `GATES`; `test_measurement_status.py` prüft,
dass die Liste mit den Gattern im Swift-Code übereinstimmt.
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

GATES = {
    "focusblox-corpus.json": [
        "ContextWordLearningReportTests",
        "FocusBloxCalibrationTests",
        "RecognitionRuleCorpusTests",
        "RuleLeaveOneOutReportTests",
        "SelfConsistencyReportTests",
    ],
    "selfconsistency-run.json": [
        "SelfConsistencyReportTests",
    ],
}


def main_checkout(checkout: pathlib.Path):
    """Der Hauptordner zu einem Worktree unter `.claude/worktrees/<name>`, sonst None."""
    parts = checkout.parts
    index = max((i for i, part in enumerate(parts) if part == ".claude"), default=None)
    if index is None or index == 0 or index + 2 >= len(parts) or parts[index + 1] != "worktrees":
        return None
    return pathlib.Path(*parts[:index])


def locate(name: str, checkout: pathlib.Path):
    own = checkout / "docs" / "reference" / name
    if own.exists():
        return own
    main = main_checkout(checkout)
    if main is not None and (main / "docs" / "reference" / name).exists():
        return main / "docs" / "reference" / name
    return None


def status(checkout: pathlib.Path):
    """(Suite, gelaufen, Grund) je gegatterter Suite, nach Name sortiert."""
    missing = {name for name in GATES if locate(name, checkout) is None}
    suites = sorted({suite for listed in GATES.values() for suite in listed})
    rows = []
    for suite in suites:
        lacking = sorted(name for name, listed in GATES.items() if suite in listed and name in missing)
        rows.append((suite, not lacking, ", ".join(lacking)))
    return rows


def render(rows, markdown: bool) -> str:
    skipped = [row for row in rows if not row[1]]
    if markdown:
        lines = ["### Messstrecken", ""]
        if not skipped:
            lines.append(f"Alle {len(rows)} Messstrecken liefen mit Daten.")
        else:
            lines.append(f"**{len(skipped)} von {len(rows)} Messstrecken übersprungen** – „grün“ heißt hier "
                         "„nicht gemessen“, nicht „bestanden“.")
        lines += ["", "| Suite | Ergebnis |", "|---|---|"]
        lines += [f"| `{suite}` | {'gelaufen' if ran else 'übersprungen, fehlt: ' + why} |" for suite, ran, why in rows]
        return "\n".join(lines)
    if not skipped:
        return f"[sim] Messstrecken: alle {len(rows)} liefen mit Daten."
    lines = [f"[sim] Messstrecken: {len(skipped)} von {len(rows)} übersprungen (nicht gemessen, nicht bestanden):"]
    lines += [f"[sim]   {suite} – fehlt: {why}" for suite, ran, why in skipped]
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--markdown", action="store_true", help="Tabelle für die CI-Zusammenfassung")
    parser.add_argument("--checkout", type=pathlib.Path, default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    print(render(status(args.checkout), args.markdown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
