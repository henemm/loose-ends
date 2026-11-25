"""Auswertung des Wiederholungslaufs für #978 Schnitt 2.

Liest die exportierten `mac-gallery-<label>-click`-Anhänge (Ordner von `xcresulttool export attachments` mit
`manifest.json`) und das Panel-Protokoll (`log show --style compact`, Kategorie `MenuBarPanel`, Zeiten in UTC).
Je Arm (Return, Open-App, Kontrollarm) zählt es Nenner (alle Wiederöffnungen), Zähler („panel not open“) und Rate;
je Fall baut es die Zeitachse ab dem Klick. Die Ausgabe enthält nur Zeiten, Typnummern und PIDs: keinen Fenstertitel,
keine Bundle-ID, keinen Stapel.

Mit `--expected N` prüft es den Nenner je aktivem Arm gegen N (Iterationen je Test) und nennt jede Abweichung; aktiv sind
die Arme aus `--arms`, ohne die Angabe Return, Open-App und jeder Arm mit mindestens einem Klickanhang. Je Arm zählt es
den Klickweg aus der Anhangszeile `how:` (seit #978 S5 short-click; dazu statusitem, cgevent, xcuicoordinate). Als Beleg
für den Nutzerweg zählt nur short-click.

Seit #978 S5 nennt der Bericht je Wiederöffnungsklick die Haltedauer: key → Maus hoch, wenn das Maus-hoch im 3-s-Fenster
des Monitors nach `key` liegt, sonst „kurz (kein Maus-hoch)“ (beim kurzen Klick bleibt das Ereignis beim Statusobjekt).

Seit #978 S3 v4 zählt es auch die Haltedauer-Probe (`mac-gallery-hold-<d>-<n>-click`, Arme hold-1.0 und hold-0.1):
je Arm Nenner, zu, offen und Rate, je Klick key → Maus hoch aus dem Panel-Protokoll, den Abgleich mit der Haltedauer des
globalen Monitors im Testläufer (oder `monitor saw nothing`) und die vorab festgelegte Entscheidungsregel (Spec Punkt 6).

Aufruf: python3 scripts/mac_panel_repeat_summary.py --raw <ordner> [--raw <ordner> …] --log <datei> --out <datei>
        [--expected N] [--arms return,open-app,control,hold-1.0,hold-0.1]
"""
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REOPEN_ARMS = ("return", "open-app", "control")
HOLD_ARMS = ("hold-1.0", "hold-0.1")
ARMS = REOPEN_ARMS + HOLD_ARMS
# Die beiden Pflicht-Arme laufen in jedem Wiederholungslauf; der Kontrollarm nur mit `kontrollarm`.
REQUIRED_ARMS = ("return", "open-app")
# Klickweg aus der Zeile `how:` des Anhangs (MacGalleryTests.swift), je Eintrag ein regulärer Ausdruck. Als Beleg für
# den Nutzerweg zählt nur `short-click` (#978 S5); die entfallenen v3-Klickwege sind `unbekannt`.
_HOW = ((r"short click 0\.1 s", "short-click"), (r"statusItem\.click\(\)$", "statusitem"), (r"CGEvent", "cgevent"),
        (r"XCUICoordinate", "xcuicoordinate"))
# Der Kontrollarm zuerst, weil sein Label mit dem des Return-Arms beginnt.
_ARM_PATTERN = re.compile(r"^mac-gallery-(reopen-return-control|reopen-return|reopen-open-app)-click(?:[_.]|$)")
_HOLD_PATTERN = re.compile(r"^mac-gallery-hold-(1\.0|0\.1)-\d+-click(?:[_.]|$)")
# xcresulttool trennt „1.0“/„0.1“ am Punkt wie eine Dateiendung: `mac-gallery-hold-1_0_<UUID>.0-<n>-click`.
_HOLD_SPLIT_PATTERN = re.compile(r"^mac-gallery-hold-(1|0)_\d+_[0-9A-Fa-f-]+\.(0|1)-\d+-click(?:[_.]|$)")
# Entscheidungsregel (Spec Punkt 6): je Arm mindestens 20 Klicks, 1,0 s schließt in mindestens 95 %, 0,1 s nie.
HOLD_MIN_CLICKS = 20
HOLD_LONG_MIN_RATE = 0.95
# Monitor- und Log-Dauer gelten als übereinstimmend, wenn sie höchstens so weit auseinanderliegen.
AGREEMENT_SECONDS = 0.1
_LABEL_TO_ARM = {"reopen-return-control": "control", "reopen-return": "return", "reopen-open-app": "open-app"}
# Wie lange nach dem Klick Protokollzeilen zur Zeitachse eines Falls gehören (Warten des Tests: 10 s).
TIMELINE_SECONDS = 15.0
# Fenster des Monitors in der App nach `key` (MenuBarCapture: 3 s); nur ein Maus-hoch darin gehört zum Klick.
MONITOR_SECONDS = 3.0
# Haltedauer eines Klicks mit `key`, aber ohne Maus-hoch im Monitorfenster (#978 S5).
SHORT = "kurz (kein Maus-hoch)"

_LINE = re.compile(
    r"^(?P<stamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)(?P<tz>[+-]\d{4})?\s.*?"
    r"\[com\.henning\.looseends:MenuBarPanel\]\s+(?P<message>.*)$")


def arm_of(name: str):
    """Arm eines Anhangs nach seinem Namen, `None` für alles, was kein Klickanhang der Wiederöffnung ist."""
    match = _ARM_PATTERN.match(name)
    if match:
        return _LABEL_TO_ARM[match.group(1)]
    hold = _HOLD_PATTERN.match(name)
    if hold:
        return f"hold-{hold.group(1)}"
    split = _HOLD_SPLIT_PATTERN.match(name)
    arm = f"hold-{split.group(1)}.{split.group(2)}" if split else None
    return arm if arm in ("hold-1.0", "hold-0.1") else None


def parse_click(text: str):
    """(Klickzeit in Sekunden seit 1970, Panel offen) aus dem Anhang von `assertSymbolOpensPanelWithOneClick`."""
    at = re.search(r"^click: ([0-9.]+)", text, re.M)
    state = re.search(r"panel (open|not open)\s*$", text, re.M)
    if not at or not state:
        raise ValueError("Klickanhang ohne Zeit oder Zustand")
    return float(at.group(1)), state.group(1) == "open"


def parse_hold(text: str):
    """d, Klickzeit, Panel offen und Monitor-Dauer (None bei `monitor saw nothing`) aus dem Anhang von `testHoldDurationProbe`."""
    at = re.search(r"^click: ([0-9.]+)", text, re.M)
    d = re.search(r"^d: ([0-9.]+)", text, re.M)
    result = re.search(r"^result: (open|closed)\s*$", text, re.M)
    monitor = re.search(r"^monitor hold: ([0-9.]+)", text, re.M)
    if not at or not d or not result or (not monitor and not re.search(r"^monitor saw nothing", text, re.M)):
        raise ValueError("Halteanhang ohne Zeit, d, Ergebnis oder Monitorzeile")
    return {"d": float(d.group(1)), "clicked_at": float(at.group(1)), "open": result.group(1) == "open",
            "monitor": float(monitor.group(1)) if monitor else None}


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
    """Alle Klickanhänge als (Arm, Klickzeit, offen), über alle Exportordner; Halte-Arme mit „offen“ aus `result:`."""
    found = []
    for arm, text in _click_texts(folders):
        if arm in HOLD_ARMS:
            hold = parse_hold(text)
            found.append((arm, hold["clicked_at"], hold["open"]))
        else:
            found.append((arm, *parse_click(text)))
    return found


def how_of(text: str) -> str:
    """Klickweg eines Anhangs aus seiner Zeile `how:`; ohne erkennbare Zeile `unbekannt`."""
    line = re.search(r"^how: (.*)$", text, re.M)
    for pattern, name in _HOW:
        if line and re.search(pattern, line.group(1).strip()):
            return name
    return "unbekannt"


def count_how(folders):
    """Je Arm, wie oft jeder Klickweg vorkam (leeres dict ohne Anhang)."""
    counts = {arm: {} for arm in REOPEN_ARMS}
    for arm, text in _click_texts(folders):
        if arm not in counts:
            continue
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


def _first_key(clicked_at: float, events):
    """Die erste `key`-Zeile bis `TIMELINE_SECONDS` nach dem Klick, sonst None."""
    window = [e for e in sorted(events, key=lambda e: e["time"]) if 0 <= e["time"] - clicked_at < TIMELINE_SECONDS]
    return next((e for e in window if e["kind"] == "key"), None)


def key_to_mouse_up(clicked_at: float, events):
    """Sekunden von der ersten `key`-Zeile nach dem Klick bis zur ersten Maus hoch (Monitorzeile type=2) im 3-s-Fenster
    des Monitors danach; sonst None. Ein späteres Maus-hoch gehört zu einem anderen Vorgang (#978 S5)."""
    key = _first_key(clicked_at, events)
    if key is None:
        return None
    up = next((e for e in sorted(events, key=lambda e: e["time"])
               if 0 <= e["time"] - key["time"] < MONITOR_SECONDS and e["kind"].startswith("monitor") and e["event"] == 2),
              None)
    return None if up is None else up["time"] - key["time"]


def hold_of(clicked_at: float, events):
    """Haltedauer eines Klicks: Sekunden key → Maus hoch, `SHORT` ohne Maus-hoch im Fenster, None ohne `key`."""
    if _first_key(clicked_at, events) is None:
        return None
    seconds = key_to_mouse_up(clicked_at, events)
    return SHORT if seconds is None else seconds


def agreement(monitor, log) -> str:
    """Abgleich Monitor- gegen Log-Dauer: match, mismatch, `monitor saw nothing` oder `no log`."""
    if monitor is None:
        return "monitor saw nothing"
    if log is None:
        return "no log"
    return "match" if abs(monitor - log) <= AGREEMENT_SECONDS else "mismatch"


def hold_rows(folders, events):
    """Je Halteklick: Arm, d, Klickzeit, offen, Monitor-Dauer, Log-Dauer (key → Maus hoch) und Abgleich."""
    rows = []
    for arm, text in _click_texts(folders):
        if arm not in HOLD_ARMS:
            continue
        hold = parse_hold(text)
        log = key_to_mouse_up(hold["clicked_at"], events)
        rows.append({"arm": arm, **hold, "log": log, "agreement": agreement(hold["monitor"], log)})
    return sorted(rows, key=lambda row: row["clicked_at"])


def decision(counts) -> str:
    """Entscheidungsregel aus Spec Punkt 6: bestanden, nicht bestanden oder zu wenig Klicks."""
    long, short = counts["hold-1.0"], counts["hold-0.1"]
    if long["n"] < HOLD_MIN_CLICKS or short["n"] < HOLD_MIN_CLICKS:
        return "zu wenig Klicks"
    return "bestanden" if long["rate"] >= HOLD_LONG_MIN_RATE and short["fails"] == 0 else "nicht bestanden"


def _seconds(value) -> str:
    return "–" if value is None else f"{value:.3f} s"


def hold_report(folders, counts, events):
    """Abschnitt der Haltedauer-Probe: zu/offen je Arm, Monitor gegen Log, Entscheidung, je Klick eine Zeile."""
    rows = hold_rows(folders, events)
    lines = ["", "## Haltedauer-Probe (#978 S3 v4)", "", "| Arm | Nenner | zu | offen | Rate zu |", "|---|---|---|---|---|"]
    lines += [f"| {arm} | {counts[arm]['n']} | {counts[arm]['fails']} | {counts[arm]['n'] - counts[arm]['fails']} | "
              f"{_rate(counts[arm]['rate'])} |" for arm in HOLD_ARMS]
    seen = sum(1 for row in rows if row["monitor"] is not None)
    tally = {name: sum(1 for row in rows if row["agreement"] == name)
             for name in ("match", "mismatch", "no log", "monitor saw nothing")}
    lines += ["", f"Monitor sah Ereignisse: {seen} von {len(rows)}", f"- monitor saw nothing: {tally['monitor saw nothing']}",
              f"Übereinstimmung Monitor/Log: {tally['match']}", f"- Abweichung über {AGREEMENT_SECONDS:.1f} s: {tally['mismatch']}",
              f"- ohne Log-Dauer: {tally['no log']}", "",
              f"Entscheidung: {decision(counts)} (je Arm mindestens {HOLD_MIN_CLICKS} Klicks, hold-1.0 zu ≥ "
              f"{HOLD_LONG_MIN_RATE * 100:.0f} %, hold-0.1 zu 0 %)", "",
              "| Klick | Arm | Ergebnis | Monitor | key → Maus hoch | Abgleich |", "|---|---|---|---|---|---|"]
    lines += [f"| {row['clicked_at']:.3f} | {row['arm']} | {'open' if row['open'] else 'closed'} | {_seconds(row['monitor'])} | "
              f"{_seconds(row['log'])} | {row['agreement']} |" for row in rows]
    return lines


def reopen_hold_report(folders, events):
    """Abschnitt „Haltedauer je Klick“: je Wiederöffnungsklick Arm, Ergebnis und Haltedauer (#978 S5)."""
    rows = sorted((at, arm, opened) for arm, at, opened in clicks(folders) if arm in REOPEN_ARMS)
    lines = ["", "## Haltedauer je Klick", "", "| Klick | Arm | Ergebnis | Haltedauer |", "|---|---|---|---|"]
    for at, arm, opened in rows:
        hold = hold_of(at, events)
        shown = hold if isinstance(hold, str) else _seconds(hold)
        lines.append(f"| {at:.3f} | {arm} | {'open' if opened else 'not open'} | {shown} |")
    return lines


def _rate(rate) -> str:
    return "–" if rate is None else f"{rate * 100:.1f} %"


def _entry(entry) -> str:
    fields = " ".join(f"{key}={entry[key]}" for key in ("event", "cg", "source", "target") if entry[key] is not None)
    return f"- +{entry['offset']:.3f} s {entry['kind']} {fields}".rstrip()


def report(folders, log_text: str, expected=None, arms=None) -> str:
    """Markdown: Ratentabelle je Arm, Nennerprüfung, Klickweg, danach je Fall die Zeitachse."""
    counts = count_arms(folders)
    hold = any(counts[arm]["n"] for arm in HOLD_ARMS) or any(arm in HOLD_ARMS for arm in arms or ())
    shown = ARMS if hold else REOPEN_ARMS
    lines = ["## #978 Panel-Wiederholung", "", "| Arm | Nenner | Zähler | Rate |", "|---|---|---|---|"]
    lines += [f"| {arm} | {counts[arm]['n']} | {counts[arm]['fails']} | {_rate(counts[arm]['rate'])} |" for arm in shown]
    if expected is not None:
        found = deviations(counts, expected, arms)
        lines += ["", f"Soll-Nenner je aktivem Arm: {expected}"] + (found or ["- keine Abweichung"])
    lines += ["", "Klickweg je Arm (Beleg für den Nutzerweg nur short-click):"]
    order = [name for _, name in _HOW]
    for arm, ways in count_how(folders).items():
        ranked = sorted(ways.items(), key=lambda way: (order.index(way[0]) if way[0] in order else len(order), way[0]))
        lines.append(f"- {arm}: " + (", ".join(f"{name} {n}" for name, n in ranked) or "–"))
    events = parse_panel_log(log_text)
    lines += reopen_hold_report(folders, events)
    if hold:
        lines += hold_report(folders, counts, events)
    failures = sorted((at, arm) for arm, at, opened in clicks(folders) if not opened and arm in REOPEN_ARMS)
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
    parser.add_argument("--arms", help="aktive Arme, kommagetrennt (return,open-app,control,hold-1.0,hold-0.1)")
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
