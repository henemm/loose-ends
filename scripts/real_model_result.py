#!/usr/bin/env python3
"""Ein Satz am Ende von `sim.sh real-model` (#531): bestanden, fehlgeschlagen, übersprungen, oder nicht gelaufen.

Liest das Ergebnisbündel (`.xcresult`), nicht das Log: Xcode 27 schreibt die Zeilen von Swift Testing nicht
mehr in die Ausgabe von xcodebuild (Henning, 2026-10-20: nach „Testing started“ kam nichts), das Bündel
kennt jeden Test mit Ergebnis und Meldung. Nur Standardbibliothek. Reine Funktionen oben, I/O in main().

Aufruf: real_model_result.py <xcresult>   Exit 0 bestanden, 1 fehlgeschlagen, 2 übersprungen, 3 unbekannt.
"""
import json
import subprocess
import sys
from pathlib import Path

SUITE = "RealModelTests"
PASSED, FAILED, SKIPPED, UNKNOWN = 0, 1, 2, 3


def test_cases(nodes, inside=False):
    """Alle Testfälle der Suite aus `xcresulttool get test-results tests`, mit ihren Meldungen."""
    found = []
    for node in nodes or []:
        name = node.get("name") or ""
        here = inside or SUITE in name or SUITE in (node.get("nodeIdentifier") or "")
        if node.get("nodeType") == "Test Case" and here:
            found.append({
                "name": name,
                "result": node.get("result") or "unknown",
                "messages": messages(node.get("children")),
            })
        else:
            found.extend(test_cases(node.get("children"), here))
    return found


def messages(nodes):
    """Meldungen unter einem Testfall (Fehler, Übersprungen-Grund), rekursiv, ohne Leerzeilen."""
    out = []
    for node in nodes or []:
        if node.get("nodeType") not in ("Test Case", "Test Suite"):
            for key in ("name", "details"):
                text = (node.get(key) or "").strip()
                if text and text not in out:
                    out.append(text)
        out.extend(m for m in messages(node.get("children")) if m not in out)
    return out


def verdict(summary, tests):
    """(Exit-Code, Zeilen zum Zeigen, der eine Satz)."""
    cases = test_cases((tests or {}).get("testNodes"))
    lines = []
    for case in cases:
        lines.append(f"{case['result']:8} {case['name']}")
        lines.extend(f"         {m}" for m in case["messages"])
    results = {c["result"] for c in cases}
    if not cases:
        total = (summary or {}).get("totalTestCount")
        if total == 0:
            return SKIPPED, lines, ("Modelltests ÜBERSPRUNGEN: kein Test der Suite lief. Die Variable LOOSEENDS_REAL_MODEL "
                                    "kam nicht beim Testlauf an.")
        return UNKNOWN, lines, "Kein Testfall von RealModelTests im Ergebnisbündel; der Lauf ist vor den Tests abgebrochen."
    if "Failed" in results:
        reason = next((m for c in cases if c["result"] == "Failed" for m in c["messages"]), "")
        tail = f" Grund: {reason}" if reason else ""
        return FAILED, lines, f"Modelltests gegen das echte Modell FEHLGESCHLAGEN.{tail}"
    if results <= {"Skipped"}:
        reason = next((m for c in cases for m in c["messages"]), "")
        tail = f" Grund: {reason}" if reason else " (Variable nicht gesetzt oder Apple Intelligence aus)"
        return SKIPPED, lines, f"Modelltests ÜBERSPRUNGEN, nicht gelaufen.{tail}"
    if "Passed" in results:
        return PASSED, lines, "Modelltests gegen das echte Modell BESTANDEN: Das Modell lief auf diesem Mac."
    return UNKNOWN, lines, f"Modelltests mit unbekanntem Ergebnis: {', '.join(sorted(results))}."


def read(bundle, kind):
    raw = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(bundle), "--compact"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(raw)


def main(argv):
    if len(argv) != 2:
        print("Aufruf: real_model_result.py <xcresult>", file=sys.stderr)
        return UNKNOWN
    bundle = Path(argv[1])
    if not bundle.is_dir():
        print(f"Kein Ergebnisbündel unter {bundle}; der Lauf ist vor den Tests abgebrochen.", file=sys.stderr)
        return UNKNOWN
    try:
        summary, tests = read(bundle, "summary"), read(bundle, "tests")
    except (subprocess.CalledProcessError, json.JSONDecodeError, OSError) as error:
        print(f"Ergebnisbündel nicht lesbar ({error}); Ergebnis der Modelltests unbekannt.", file=sys.stderr)
        return UNKNOWN
    code, lines, sentence = verdict(summary, tests)
    for line in lines:
        print(f"   {line}", file=sys.stderr)
    print(sentence, file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
