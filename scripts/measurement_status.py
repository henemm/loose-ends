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
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

GATES = {
    "focusblox-corpus.json": [
        "ContextWordLearningReportTests",
        "RecognitionRuleCorpusTests",
        "RuleLeaveOneOutReportTests",
        "SelfConsistencyReportTests",
    ],
    "selfconsistency-run.json": [
        "SelfConsistencyReportTests",
    ],
    "textform-run.json": [
        "TextFormModelReportTests",
    ],
    "loose-ends-rawtexts.json": [
        "RawSentenceReportTests",
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


# Der Latenzschutz aus #274: zwei Messtests, die sich ohne Sprachmodell per `Test.cancel` abmelden und die Suite
# trotzdem „passed“ melden lassen (#419). Ihr Zustand steht nur im Rohlog von xcodebuild.
LATENCY_TESTS = [
    "The first word arrives within 3 s of speech start",
    "The final text keeps the key words",
]
LATENCY_LABELS = {"measured": "gemessen (passed)", "failed": "FEHLGESCHLAGEN"}


def latency_status(log_text: str):
    """(Testname, Zustand, Grund) je Messtest; Zustand ist measured, failed oder not_measured."""
    rows = []
    for name in LATENCY_TESTS:
        state, why = "not_measured", "nicht im Log"
        pattern = re.compile(rf'Test "{re.escape(name)}" (passed after|failed|was cancelled after[^:]*: "(.*)")')
        for line in log_text.splitlines():
            match = pattern.search(line)
            if match is None:
                continue
            if match.group(1).startswith("passed"):
                state, why = "measured", ""
            elif match.group(1) == "failed":
                state, why = "failed", ""
            else:
                state, why = "not_measured", match.group(2)
        rows.append((name, state, why))
    return rows


def latency_label(state: str, why: str) -> str:
    return LATENCY_LABELS.get(state, f"NICHT gemessen: {why}")


def render_latency(rows, markdown: bool) -> str:
    if markdown:
        lines = ["### Latenzschutz (#274)", ""]
        if any(state != "measured" for _, state, _ in rows):
            lines += ["**Nicht jeder Messtest hat gemessen** – „grün“ heißt hier „nicht gemessen“, nicht „bestanden“.", ""]
        lines += ["| Test | Ergebnis |", "|---|---|"]
        lines += [f"| {name} | {latency_label(state, why)} |" for name, state, why in rows]
        return "\n".join(lines)
    lines = ["[sim] Latenzschutz (#274):"]
    lines += [f"[sim]   {name} – {latency_label(state, why)}" for name, state, why in rows]
    return "\n".join(lines)


def latency_warning(rows) -> str:
    """Annotation für den CI-Lauf, leer wenn beide Messtests gemessen haben."""
    missing = [f"{name} ({latency_label(state, why)})" for name, state, why in rows if state != "measured"]
    return f"::warning::Latenzschutz #274 nicht gemessen: {'; '.join(missing)}" if missing else ""


def report_latency(path: pathlib.Path, markdown: bool, warning: bool) -> str:
    """Bericht (oder nur die Annotation) zum Rohlog; ein fehlendes Log wird ausdrücklich genannt."""
    if not path.is_file():
        if warning:
            return f"::warning::Latenzschutz #274 nicht gemessen: kein Log ({path})"
        head = "### Latenzschutz (#274)\n\n" if markdown else "[sim] Latenzschutz (#274): "
        return f"{head}kein Log ({path}) – nicht gemessen, nicht bestanden."
    rows = latency_status(path.read_text(errors="replace"))
    return latency_warning(rows) if warning else render_latency(rows, markdown)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--markdown", action="store_true", help="Tabelle für die CI-Zusammenfassung")
    parser.add_argument("--checkout", type=pathlib.Path, default=ROOT, help=argparse.SUPPRESS)
    parser.add_argument("--latency-log", type=pathlib.Path, help="Rohlog des Laufs: Zustand des Latenzschutzes (#419)")
    parser.add_argument("--latency-warning", action="store_true",
                        help="nur die CI-Annotation zum Latenzschutz ausgeben (braucht --latency-log)")
    args = parser.parse_args(argv)
    if args.latency_warning:
        if args.latency_log is not None:
            text = report_latency(args.latency_log, False, warning=True)
            if text:
                print(text)
        return 0
    print(render(status(args.checkout), args.markdown))
    if args.latency_log is not None:
        print(("\n" if args.markdown else "") + report_latency(args.latency_log, args.markdown, warning=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
