"""Auswertung des Wiederholungslaufs für #978 Schnitt 2.

Liest die exportierten `mac-gallery-<label>-click`-Anhänge (Ordner von `xcresulttool export attachments` mit
`manifest.json`) und das Panel-Protokoll (`log show --style compact`, Kategorie `MenuBarPanel`, Zeiten in UTC).
Je Arm (Return, Open-App, Kontrollarm) zählt es Nenner (alle Wiederöffnungen), Zähler („panel not open“) und Rate;
je Fall baut es die Zeitachse ab dem Klick. Die Ausgabe enthält nur Zeiten, Typnummern und PIDs: keinen Fenstertitel,
keine Bundle-ID, keinen Stapel.

Mit `--expected N` prüft es den Nenner je aktivem Arm gegen N (Iterationen je Test) und nennt jede Abweichung; aktiv sind
die Arme aus `--arms`, ohne die Angabe Return, Open-App und jeder Arm mit mindestens einem Klickanhang. Je Arm zählt es
den Klickweg aus der Anhangszeile `how:` (statusitem, cgevent, xcuicoordinate als Rückfall).

Aufruf: python3 scripts/mac_panel_repeat_summary.py --raw <ordner> [--raw <ordner> …] --log <datei> --out <datei>
        [--expected N] [--arms return,open-app,control]
"""
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ARMS = ("return", "open-app", "control")
# Die beiden Pflicht-Arme laufen in jedem Wiederholungslauf; der Kontrollarm nur mit `kontrollarm`.
REQUIRED_ARMS = ("return", "open-app")
# Klickweg aus der Zeile `how:` des Anhangs (MacGalleryTests.swift).
_HOW = (("statusItem.click()", "statusitem"), ("CGEvent", "cgevent"), ("XCUICoordinate", "xcuicoordinate"))
# Der Kontrollarm zuerst, weil sein Label mit dem des Return-Arms beginnt.
_ARM_PATTERN = re.compile(r"^mac-gallery-(reopen-return-control|reopen-return|reopen-open-app)-click(?:[_.]|$)")
_LABEL_TO_ARM = {"reopen-return-control": "control", "reopen-return": "return", "reopen-open-app": "open-app"}
# Wie lange nach dem Klick Protokollzeilen zur Zeitachse eines Falls gehören (Warten des Tests: 10 s).
TIMELINE_SECONDS = 15.0

_LINE = re.compile(
    r"^(?P<stamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)(?P<tz>[+-]\d{4})?\s.*?"
    r"\[com\.henning\.looseends:MenuBarPanel\]\s+(?P<message>.*)$")


def arm_of(name: str):
    """Arm eines Anhangs nach seinem Namen, `None` für alles, was kein Klickanhang der Wiederöffnung ist."""
    match = _ARM_PATTERN.match(name)
    return _LABEL_TO_ARM[match.group(1)] if match else None


def parse_click(text: str):
    """(Klickzeit in Sekunden seit 1970, Panel offen) aus dem Anhang von `assertSymbolOpensPanelWithOneClick`."""
    at = re.search(r"^click: ([0-9.]+)", text, re.M)
    state = re.search(r"panel (open|not open)\s*$", text, re.M)
    if not at or not state:
        raise ValueError("Klickanhang ohne Zeit oder Zustand")
    return float(at.group(1)), state.group(1) == "open"


def _click_texts(folders):
    """(Arm, Text) je Klickanhang, über alle Exportordner."""
    for folder in folders:
        manifest = Path(folder) / "manifest.json"
        if not manifest.is_file():
            continue
        for test in json.loads(manifest.read_text()):
            for attachment in test.get("attachments", []):
                arm = arm_of(attachment.get("suggestedHumanReadableName", ""))
                if arm is not None:
                    yield arm, (Path(folder) / attachment["exportedFileName"]).read_text()


def clicks(folders):
    """Alle Klickanhänge als (Arm, Klickzeit, offen), über alle Exportordner."""
    return [(arm, *parse_click(text)) for arm, text in _click_texts(folders)]


def how_of(text: str) -> str:
    """Klickweg eines Anhangs aus seiner Zeile `how:`; ohne erkennbare Zeile `unbekannt`."""
    line = re.search(r"^how: (.*)$", text, re.M)
    for needle, name in _HOW:
        if line and needle in line.group(1):
            return name
    return "unbekannt"


def count_how(folders):
    """Je Arm, wie oft jeder Klickweg vorkam (leeres dict ohne Anhang)."""
    counts = {arm: {} for arm in ARMS}
    for arm, text in _click_texts(folders):
        name = how_of(text)
        counts[arm][name] = counts[arm].get(name, 0) + 1
    return counts


def deviations(counts, expected, arms=None):
    """Zeilen für jeden aktiven Arm, dessen Nenner nicht `expected` ist."""
    active = arms if arms is not None else [a for a in ARMS if a in REQUIRED_ARMS or counts[a]["n"]]
    return [f"- Abweichung {arm}: erwartet {expected}, gezählt {counts[arm]['n']}"
            for arm in active if counts[arm]["n"] != expected]


def count_arms(folders):
    """Je Arm Nenner `n`, Zähler `fails` und `rate` (None ohne Wiederöffnung)."""
    counts = {arm: {"n": 0, "fails": 0, "rate": None} for arm in ARMS}
    for arm, _, opened in clicks(folders):
        counts[arm]["n"] += 1
        counts[arm]["fails"] += 0 if opened else 1
    for entry in counts.values():
        if entry["n"]:
            entry["rate"] = entry["fails"] / entry["n"]
    return counts


def _number(pattern: str, text: str):
    match = re.search(pattern, text)
    return int(match.group(1)) if match else None


def _time(stamp: str, tz) -> float:
    moment = datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S.%f" if "." in stamp else "%Y-%m-%d %H:%M:%S")
    zone = datetime.strptime(tz, "%z").tzinfo if tz else timezone.utc
    return moment.replace(tzinfo=zone).timestamp()


def parse_panel_log(text: str):
    """Die Zeilen der Kategorie `MenuBarPanel` als Ereignisse: Art, Zeit, Ereignistyp, CG-Typ und Quelle-PID."""
    events = []
    for raw in text.splitlines():
        match = _LINE.match(raw)
        if not match:
            continue
        message = match.group("message")
        words = message.split()
        kind = words[1] if words[0] == "panel" and len(words) > 1 else " ".join(words[:2])
        event = _number(r"\bevent=(\d+)", message)
        if event is None:
            event = _number(r"(?:^|\s)type=(\d+)", message)
        events.append({
            "kind": kind,
            "time": _time(match.group("stamp"), match.group("tz")),
            "event": event,
            "cg": _number(r"\bcg=type=(\d+)", message),
            "source": _number(r"\bsource=(\d+)", message),
            "target": _number(r"\btarget=(\d+)", message),
        })
    return events


def timeline(clicked_at: float, events):
    """Zeitachse eines Falls: der Klick, dann jede Protokollzeile bis `TIMELINE_SECONDS` danach."""
    line = [{"kind": "click", "offset": 0.0, "event": None, "cg": None, "source": None, "target": None}]
    for event in sorted(events, key=lambda e: e["time"]):
        offset = event["time"] - clicked_at
        if 0 <= offset < TIMELINE_SECONDS:
            line.append({key: event[key] for key in ("kind", "event", "cg", "source", "target")} | {"offset": offset})
    return line


def _rate(rate) -> str:
    return "–" if rate is None else f"{rate * 100:.1f} %"


def _entry(entry) -> str:
    fields = " ".join(f"{key}={entry[key]}" for key in ("event", "cg", "source", "target") if entry[key] is not None)
    return f"- +{entry['offset']:.3f} s {entry['kind']} {fields}".rstrip()


def report(folders, log_text: str, expected=None, arms=None) -> str:
    """Markdown: Ratentabelle je Arm, Nennerprüfung, Klickweg, danach je Fall die Zeitachse."""
    counts = count_arms(folders)
    lines = ["## #978 Panel-Wiederholung", "", "| Arm | Nenner | Zähler | Rate |", "|---|---|---|---|"]
    lines += [f"| {arm} | {c['n']} | {c['fails']} | {_rate(c['rate'])} |" for arm, c in counts.items()]
    if expected is not None:
        found = deviations(counts, expected, arms)
        lines += ["", f"Soll-Nenner je aktivem Arm: {expected}"] + (found or ["- keine Abweichung"])
    lines += ["", "Klickweg je Arm:"]
    for arm, ways in count_how(folders).items():
        lines.append(f"- {arm}: " + (", ".join(f"{name} {n}" for name, n in sorted(ways.items())) or "–"))
    events = parse_panel_log(log_text)
    failures = sorted((at, arm) for arm, at, opened in clicks(folders) if not opened)
    lines += ["", f"Fälle: {len(failures)}"]
    for at, arm in failures:
        lines += ["", f"### Fall {arm}, Klick {at:.3f}", ""]
        lines += [_entry(entry) for entry in timeline(at, events)]
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--raw", action="append", required=True, help="Exportordner mit manifest.json")
    parser.add_argument("--log", required=True, help="Panel-Protokoll aus log show")
    parser.add_argument("--out", required=True, help="Zieldatei (Markdown)")
    parser.add_argument("--expected", type=int, help="Iterationen je Test: erwarteter Nenner je aktivem Arm")
    parser.add_argument("--arms", help="aktive Arme, kommagetrennt (return,open-app,control)")
    args = parser.parse_args(argv)
    arms = None
    if args.arms is not None:
        arms = [arm.strip() for arm in args.arms.split(",") if arm.strip()]
        unknown = [arm for arm in arms if arm not in ARMS]
        if unknown:
            parser.error(f"unbekannter Arm: {', '.join(unknown)}")
    log = Path(args.log)
    text = report([Path(raw) for raw in args.raw], log.read_text() if log.is_file() else "", args.expected, arms)
    Path(args.out).write_text(text)
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
