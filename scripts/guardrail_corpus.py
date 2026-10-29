"""Gerätekorpus und Zählung für den iPhone-Lauf der Guardrail-Messung (#71, Schnitt 2b-2).

build <focusblox.json> <ziel.json> [--heikel <pfad>]: 100 heikle Texte + persönliche Sätze, Ziel nie im Repo.
count <ergebnis.json>: Zahl der gemessenen Aufrufe (Erfolg, guardrail, refusal), je Eintrag × Durchlauf einmal.
Ausgaben sind nur Zahlen, nie ein Satz.
"""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_HEIKEL = HERE.parent / "Measurement" / "guardrail-corpus.json"
MEASURED_KINDS = {"guardrail", "refusal"}


def fail(message):
    print(f"guardrail_corpus: {message}", file=sys.stderr)
    sys.exit(1)


def repo_root():
    proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=HERE, capture_output=True, text=True)
    if proc.returncode != 0:
        fail("Repo-Wurzel nicht ermittelbar (git rev-parse)")
    return Path(proc.stdout.strip()).resolve()


def build(focusblox, target, heikel_path):
    target = Path(target).resolve()
    if target.is_relative_to(repo_root()):
        fail("Zielpfad liegt im Repo, persönliche Sätze dürfen dort nicht landen")
    heikel = json.loads(Path(heikel_path).read_text())
    if len(heikel) != 100:
        fail(f"{len(heikel)} heikle Einträge statt 100")
    alltag = [{"id": f"alltag-{i}", "lang": s["lang"], "text": s["rawText"], "form": "alltag"}
              for i, s in enumerate(json.loads(Path(focusblox).read_text()))]
    if not alltag:
        fail("keine persönlichen Sätze im FocusBlox-Korpus")
    entries = [{key: e[key] for key in ("id", "lang", "text", "form")} for e in heikel] + alltag
    ids = [e["id"] for e in entries]
    if len(set(ids)) != len(ids):
        fail(f"{len(ids) - len(set(ids))} doppelte Id(s)")
    unknown = [i for i in ids if not i.startswith(("gr-", "alltag-"))]
    if unknown:
        fail(f"{len(unknown)} Id(s) ohne Präfix gr- oder alltag-")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(entries, ensure_ascii=False, indent=1))
    print(f"heikel {len(heikel)}, Alltag {len(alltag)}, gesamt {len(entries)}")


def count(result_path):
    results = json.loads(Path(result_path).read_text()).get("results", [])
    measured = {(r.get("entryID"), r.get("runIndex", 0)) for r in results
                if not r.get("error") or r.get("errorKind") in MEASURED_KINDS}
    print(len(measured))


def main(args):
    if len(args) >= 3 and args[0] == "build":
        heikel = DEFAULT_HEIKEL
        if len(args) == 5 and args[3] == "--heikel":
            heikel = args[4]
        elif len(args) != 3:
            fail("Aufruf: build <focusblox.json> <ziel.json> [--heikel <pfad>]")
        build(args[1], args[2], heikel)
    elif len(args) == 2 and args[0] == "count":
        count(args[1])
    else:
        fail("Aufruf: build <focusblox.json> <ziel.json> [--heikel <pfad>] | count <ergebnis.json>")


if __name__ == "__main__":
    main(sys.argv[1:])
