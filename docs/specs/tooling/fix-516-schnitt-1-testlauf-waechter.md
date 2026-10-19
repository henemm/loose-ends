---
entity_id: fix-516-schnitt-1-testlauf-waechter
type: bugfix
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: fix-516-testlauf-waechter
---

# Spec: #516 Schnitt 1 — Stille-Wächter für hängende Testläufe

## Approval

- [ ] Approved

## Purpose

Ein hängender `xcodebuild`-Lauf soll die rechnerweite Testsperre `/tmp/loose-ends-testlauf.lock` (#341/#413) nicht mehr
unbegrenzt halten: Bleibt der Lauf länger als eine Frist stumm, wird er beendet, die Meldung ist sichtbar, die Sperre wird frei.

**Hat es bisher funktioniert?** Der Hänger selbst ist ein bekanntes Xcode-Muster (Quellen im Ticket). Neu ist die Wirkung:
vor #341 blockierte er nur die eigene Sitzung, seit der rechnerweiten Sperre alle Sitzungen. Drei Fälle am 2026-10-17:
1 h, 4 h 12 min (je `sim-unit`/`test-proof`, Simulator iPhone 17) und ein iPad-Lauf, bei dem CoreSimulatorService selbst
feststeckte. Letzte Logzeile jeweils `IDESchemeActionSDKRecord … invalidDigitCount(94232)`.

**Ursache (belegt):** `run_xcodebuild` kennt keine Zeitgrenze. Bleibt `xcodebuild` stumm, wartet die Pipeline
`xcodebuild | tee | xcbeautify` ewig, das Skript endet nie, der EXIT-Trap gibt die Sperre nie frei.

**Nachgestellt (2026-10-19):** `run_xcodebuild` wörtlich aus `sim.sh`, `xcodebuild`-Stub gibt eine Zeile aus und schläft 600 s.
Nach 8 s läuft der Lauf weiter, nichts beendet ihn.

**Ohne Modell:** reine Shell-Logik, kein Sprachverstehen.

**Alternative:** Gesamtzeitgrenze je Befehl (`timeout`); verworfen, weil die längste gesunde Laufdauer nicht gemessen ist
(vorhandene Logs sind xcbeautify-Ausgabe ohne Zeitstempel). Sie würde einen langen, gesunden Lauf töten oder einen Hänger zu
lange dulden. Die Stille trennt beides ohne Annahme über die Laufdauer. Kein ADR wird gekippt.

**Nicht Teil dieses Schnitts:** die Warteliste (Fairness der Wartenden, zweiter Punkt aus den Ticket-Kommentaren) — Schnitt 2,
eigener Teil-Workflow unter #516.

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `run_xcodebuild` (Zeile 227–240), `BUILD_LOG`, `SESSION_DERIVED_DATA`, `acquire_testlock`/`release_testlock` und
  `trap release_testlock EXIT` (Zeile 85–177)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/test_sim_run_xcodebuild.py` | test | Zieht `run_xcodebuild()` wörtlich aus `sim.sh` (Funktion nicht umbenennen); bekommt die neuen Fälle |
| `scripts/test_sim_lock.py` | test | Sperrtests, bleiben unverändert grün |
| `CLAUDE.md` | doc | Absatz „Parallele Sitzungen“ nennt Frist, Variable und Meldung |
| `LOOSEENDS_LOCK_MAX`, `LOOSEENDS_LOCK_REPORT` | muster | Zeitgrenzen als Umgebungsvariable mit Vorgabe; `LOOSEENDS_SILENCE_MAX` folgt dem Muster |
| `xcodebuild`, `tee`, `xcbeautify`, `kill`, `pgrep`, `stat -f %m` | werkzeug | BSD-Varianten auf macOS |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | Stille-Wächter in `run_xcodebuild`, Meldung, Markierungsdatei |
| `scripts/test_sim_run_xcodebuild.py` | MODIFY | Neue Fälle (siehe Test Plan) |
| `CLAUDE.md` | MODIFY | Absatz „Parallele Sitzungen“ ergänzt |

Geschätzt +120 LoC, 3 Dateien. Kein Produktcode, keine Berechtigungen, keine AppStorage-Schlüssel, keine Info.plist.
**Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung.

## Definition of Done

- [ ] Stummer `xcodebuild` wird nach der Frist beendet, Meldung sichtbar, Sperre frei (AC-1, AC-3, AC-4)
- [ ] Nur der eigene Lauf wird beendet (AC-2)
- [ ] Gesunder Lauf unverändert, keine Reste (AC-5)
- [ ] `CLAUDE.md` ergänzt (AC-6)
- [ ] Alle Skripttests in `scripts/` grün, einschließlich der bestehenden Sperrtests

## Implementation Details

Neuer Hintergrundprozess in `run_xcodebuild`, gestartet vor der Pipeline, beendet nach ihr:

1. Schleife im Takt von `LOOSEENDS_SILENCE_POLL` (Vorgabe 10 s, für Tests kürzer): Alter von `$BUILD_LOG` = jetzt − `stat -f %m`.
2. Ist das Alter > `LOOSEENDS_SILENCE_MAX` (Vorgabe 900 s): Markierungsdatei `$SESSION_DERIVED_DATA/xcodebuild.hung` schreiben,
   Meldung auf stderr, dann die `xcodebuild`-Prozesse suchen, deren Kommandozeile `-derivedDataPath $SESSION_DERIVED_DATA` enthält
   (`pgrep -f`), deren Kinder (`pkill -P`) und sie selbst mit TERM beenden, nach 5 s mit KILL.
3. Nach der Pipeline: Wächter beenden (`kill`, `wait`), Markierungsdatei prüfen; existiert sie, `rm` und `return 1`.
   Die Markierung entscheidet, nicht der Pipeline-Status (mit und ohne `pipefail` gleich).
4. Das Log wird vor dem Start geleert/angelegt, damit die Stille ab Lauf-Beginn zählt und nicht am Alter eines früheren Logs.

## Test Plan

Skripttests, RED zuerst. Wie bestehend: `run_xcodebuild` wörtlich aus `sim.sh`, `xcodebuild`/`xcbeautify` als Stubs im PATH,
Frist per `LOOSEENDS_SILENCE_MAX=2`, Takt `LOOSEENDS_SILENCE_POLL=1`.

| Test | Prüft |
|---|---|
| `test_silent_xcodebuild_is_killed_after_deadline` | Stub: eine Zeile, dann `exec sleep 600`; Lauf endet binnen weniger Sekunden, Exitcode ≠ 0, Stub-Prozess tot (AC-1, AC-3) |
| `test_hang_detected_without_pipefail` | dieselbe Prüfung ohne `set -o pipefail` (AC-3) |
| `test_hang_message_names_deadline_last_line_and_simulator_service` | stderr enthält „abgebrochen“, die Frist, die letzte Logzeile, „CoreSimulatorService“ (AC-4) |
| `test_lock_released_after_hang` | Rahmenskript mit `acquire_testlock` und EXIT-Trap: Sperrverzeichnis nach dem Abbruch weg (AC-3) |
| `test_other_session_xcodebuild_survives` | zweiter Stub mit anderem `-derivedDataPath` lebt nach dem Abbruch weiter (AC-2) |
| `test_talkative_run_is_not_aborted` | Stub schreibt jede Sekunde eine Zeile, länger als die Frist, endet regulär: Exitcode 0 (AC-5) |
| `test_no_leftovers_after_normal_run` | kein Wächterprozess, keine Markierungsdatei (AC-5) |

Zusätzlich: bestehende Fälle in `test_sim_run_xcodebuild.py`, `test_sim_lock.py`, `test_sim_proof.py` bleiben grün.

## Acceptance Criteria

- **AC-1:** Given `xcodebuild` schreibt länger als `LOOSEENDS_SILENCE_MAX` (Vorgabe 900 s) nichts in `$BUILD_LOG`, When `run_xcodebuild` läuft, Then wird der `xcodebuild` dieses Laufs beendet (TERM, nach 5 s KILL).
- **AC-2:** Given parallel läuft der `xcodebuild` einer anderen Sitzung (anderer `-derivedDataPath`), When der Wächter auslöst, Then bleibt dieser Prozess unberührt; Kinder des beendeten Prozesses werden mitbeendet.
- **AC-3:** Given der Wächter hat ausgelöst, When `run_xcodebuild` zurückkehrt, Then ist der Exitcode ≠ 0 (mit und ohne `pipefail`, über Markierungsdatei), das Skript endet, der EXIT-Trap läuft und die Sperre ist frei.
- **AC-4:** Given der Wächter hat ausgelöst, When die Meldung erscheint, Then steht sie auf stderr und nennt „hängt seit N min, abgebrochen“, die Frist, die letzte Logzeile und „Ein Neustart von CoreSimulatorService kann nötig sein“; der Wächter startet den Dienst nicht selbst neu.
- **AC-5:** Given ein Lauf, der laufend Zeilen schreibt oder vor Ablauf der Frist endet, When er fertig ist, Then sind Exitcode und Ausgabe wie bisher, kein Wächterprozess läuft weiter und keine Markierungsdatei bleibt.
- **AC-6:** `CLAUDE.md`, Absatz „Parallele Sitzungen“, nennt Frist (15 min Stille), `LOOSEENDS_SILENCE_MAX` und die Abbruchmeldung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Werkzeugänderung ohne Architekturwirkung auf das Produkt; keine bestehende Entscheidung wird gekippt.

## Offener Punkt

15 min ist eine Schätzung; der längste stille Abschnitt eines gesunden Laufs ist nicht gemessen. Darum nennt die Meldung Frist und
letzte Logzeile (falscher Abbruch erkennbar), und die Frist ist per Umgebungsvariable änderbar.

## Changelog

- 2026-10-19: Spec erstellt (Schnitt 1 von #516; Warteliste folgt als Schnitt 2).
