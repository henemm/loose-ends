# Context: fix-516-testlauf-waechter

## Request Summary
Ein hängender `xcodebuild`-Lauf hält die rechnerweite Testsperre (`/tmp/loose-ends-testlauf.lock`, #341/#413) unbegrenzt.
Ein Lauf, der still bleibt, soll nach einer Frist beendet werden, die Sperre soll frei werden, die Meldung sichtbar sein.

## Reproduktion (2026-10-19)
`run_xcodebuild` wörtlich aus `scripts/sim.sh` gezogen, `xcodebuild`-Stub gibt eine Zeile aus und schläft 600 s.
Ergebnis: nach 8 s läuft der Lauf weiter, nichts beendet ihn. Gleicher Zustand wie die zwei echten Hänger in #516
(1 h und 4 h 12 min, letzte Logzeile `IDESchemeActionSDKRecord … invalidDigitCount(94232)`, bekanntes Xcode-Muster,
Quellen im Ticket). Vor #341 blockierte ein Hänger nur die eigene Sitzung; seit der rechnerweiten Sperre alle.

## Related Files
| Datei | Relevanz |
|---|---|
| `scripts/sim.sh` `run_xcodebuild` (Zeile 227–240) | Einziger Aufrufpunkt für `xcodebuild` (build, test, mac-build, test-proof, watch-test-proof, real-model). Pipeline `xcodebuild … \| tee $BUILD_LOG \| xcbeautify`. Hier kommt der Wächter hin. |
| `scripts/sim.sh` `acquire_testlock`/`release_testlock`, `trap release_testlock EXIT` (Zeile 85–177) | Sperre wird beim Skriptende freigegeben; endet der Kindprozess, endet das Skript und der Trap greift. |
| `scripts/test_sim_run_xcodebuild.py` | Vorhandenes Muster: `run_xcodebuild` wörtlich aus `sim.sh` ziehen, `xcodebuild`/`xcbeautify` als Stubs. Hier kommt der RED-Test hin. |
| `scripts/test_sim_lock.py` | Sperrtests; bleiben unverändert. |
| `CLAUDE.md` Absatz „Parallele Sitzungen" | Muss um die Frist ergänzt werden (DoD). |

## Existing Patterns
- Zeitgrenzen über Umgebungsvariablen mit Vorgabe: `LOOSEENDS_LOCK_MAX`, `LOOSEENDS_LOCK_REPORT`, `LOOSEENDS_LOCK_POLL`. Die Frist folgt diesem Muster (`LOOSEENDS_SILENCE_MAX`).
- Skripttests ziehen die Funktion aus `sim.sh` und stubben `xcodebuild` (PATH-Vorrang).
- `timeout`/`gtimeout` (coreutils) ist installiert, `sim.sh` benutzt es schon (Zeile 671, 725). Es begrenzt aber die Gesamtdauer, nicht die Stille.

## Analyse (Ursache, Lösungsweg, Alternative)
- **Ursache:** `run_xcodebuild` kennt keine Zeitgrenze. Bleibt `xcodebuild` stumm (Hänger nach dem Bau beim Teststart), wartet die Pipeline ewig, das Skript endet nie, der EXIT-Trap läuft nie, die Sperre bleibt.
- **Lösungsweg (Empfehlung):** Stille-Wächter. Ein Hintergrundprozess prüft, wann `$BUILD_LOG` zuletzt geschrieben wurde (`tee` schreibt jede Zeile). Ist die Stille länger als `LOOSEENDS_SILENCE_MAX` (Vorgabe 15 min), beendet er den `xcodebuild` dieses Laufs (TERM, nach 5 s KILL), schreibt die Meldung „hängt seit N min, abgebrochen" und legt eine Markierung ab. `run_xcodebuild` endet danach mit Fehlercode, das Skript endet, der Trap gibt die Sperre frei. Der Wächter endet mit dem Lauf.
- **Warum Stille statt Gesamtzeit:** Bau und Testlauf dauern legitim lange, schreiben aber laufend Zeilen. Ein Hänger schreibt nichts. Die Stille trennt beides ohne Annahme über die Laufdauer.
- **Alternative:** Gesamtzeitgrenze je Befehl (`timeout`). Einfacher, aber ohne Beleg für die richtige Grenze: Die vorhandenen Logs sind xcbeautify-Ausgabe ohne Zeitstempel, die längste legitime Dauer lässt sich daraus nicht messen. Sie würde einen langen, gesunden Lauf töten oder einen Hänger zu lange dulden. Kein ADR wird dadurch gekippt.
- **Ohne Modell:** reine Shell-Logik, kein Sprachverstehen.
- **Offener Punkt:** 15 min ist eine Schätzung. Der längste stille Abschnitt eines gesunden Laufs ist nicht gemessen. Im Abbruchfall nennt die Meldung deshalb Frist und letzte Logzeile, damit ein falscher Abbruch erkennbar ist. Die Frist ist per Umgebungsvariable änderbar.

## Dependencies
- Upstream: `xcodebuild`, `tee`, `xcbeautify`, `pgrep`/`kill`, `stat -f %m` (BSD).
- Downstream: alle `sim.sh`-Befehle mit Bau oder Test (`build`, `unit`, `sim-unit`, `test`, `test-proof`, `watch-test-proof`, `mac-build`, `real-model`), CI-Jobs, die `sim.sh` aufrufen.

## Existing Specs
Keine Spec für `sim.sh`; Verhalten steht in `CLAUDE.md` und in den Kommentaren in `sim.sh`. Vorarbeit: `docs/artifacts/fix-341-testlaeufe-verlaesslich/`.

## Risks & Considerations
- **Falscher Abbruch** eines gesunden, aber lange stillen Laufs (z. B. langer einzelner UI-Test): Frist großzügig, per Umgebungsvariable änderbar, Meldung nennt die letzte Logzeile.
- **Welcher Prozess:** Beenden darf nur den `xcodebuild` dieses Laufs, nicht den anderer Sitzungen. Kennzeichen: eigener `-derivedDataPath $SESSION_DERIVED_DATA` (je Worktree eindeutig).
- **Kinder von xcodebuild** (Testhost im Simulator) können nach dem Abbruch weiterleben; prüfen, ob `pkill -P` nötig ist.
- **Pipeline-Exitcode:** `run_xcodebuild` läuft mit und ohne `pipefail`; der Abbruch muss über eine Markierungsdatei signalisiert werden, nicht über den Pipeline-Status.
- Umfang: `sim.sh` (~25 LoC), ein Test (~50 LoC), ein Absatz in `CLAUDE.md`. Innerhalb der Limits.
- Der Arbeitsstand liegt auf dem Zweig `fix-419-latenzschutz` (gemergt) und muss vor dem Code auf `origin/main` aufsetzen (Rebase-Gate).

## Ergänzung aus den Ticket-Kommentaren (2026-10-17)
- **Dritter Hänger, anderer Simulator (iPad):** CoreSimulatorService selbst steckt fest (`simctl create` und „Shutting Down“ hängen ebenfalls). Die Abbruchmeldung des Wächters nennt deshalb zusätzlich: „Ein Neustart von CoreSimulatorService kann nötig sein“. Der Wächter startet ihn nicht selbst neu (würde Läufe anderer Sitzungen töten).
- **Zweiter Punkt (Warteliste):** Wartende fragen im eigenen Takt per `mkdir`, wer zufällig zuerst nachfragt, gewinnt. Das ist ein anderes Ziel als der Wächter (Fairness statt Hänger) und berührt dieselbe Datei `sim.sh`. Schnitt 2, eigener Teil-Workflow unter demselben Ticket #516.

## Analysis

### Type
Bug

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/sim.sh | MODIFY | Stille-Wächter in `run_xcodebuild`, Meldung mit Frist, letzter Logzeile, Hinweis CoreSimulatorService |
| scripts/test_sim_run_xcodebuild.py | MODIFY | Test: stummer `xcodebuild`-Stub wird nach der Frist beendet, Meldung sichtbar, Sperre frei |
| CLAUDE.md | MODIFY | Absatz „Parallele Sitzungen“ um die Frist ergänzt |

### Scope Assessment
- Files: 3
- Estimated LoC: +~120/-0 (Schnitt 1), Schnitt 2 (Warteliste) zusätzlich ~+130
- Risk Level: MEDIUM (falscher Abbruch eines gesunden, lange stillen Laufs; Frist per `LOOSEENDS_SILENCE_MAX`, Vorgabe 15 min, änderbar)

### Technical Approach
Stille-Wächter statt Gesamtzeitgrenze (Details im Abschnitt „Analyse“ oben). Ohne Modell, reine Shell-Logik.
Alternative: Gesamtzeitgrenze je Befehl via `timeout`; verworfen, weil die längste gesunde Laufdauer nicht gemessen ist. Kein ADR wird gekippt.
Schnitt 2 (Warteliste mit `queue`-Datei, nur der Kopf nimmt die Sperre, tote Einträge übersprungen) folgt danach, damit jeder Schnitt in die Limits passt.

### Dependencies
`xcodebuild`, `tee`, `xcbeautify`, `kill`, `stat -f %m`; betrifft alle `sim.sh`-Befehle mit Bau oder Test.

### Open Questions
- [x] Frist: 15 min als Vorgabe, per Umgebungsvariable änderbar; kein weiterer PO-Input nötig.
