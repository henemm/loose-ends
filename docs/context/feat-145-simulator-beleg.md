# Context: feat-145-simulator-beleg (Schnitt 1 von #145)

## Request Summary
`scripts/sim.sh` bekommt einen Befehl, der den zum Ticket gehörenden Ablauf per UI-Test im Simulator
durchspielt und daraus maschinell einen Beleg `simulator-run.txt` (Zeitstempel, `HEAD`, Prüfsummen der
geänderten Produktionsdateien, wörtliches Testergebnis, Screenshot-Pfad) plus Screenshot im
Artefakt-Ordner des Workflows erzeugt. Das Erzwingen (Gate vor `phase8_complete`) ist Schnitt 2 im
Plugin-Repo und **nicht** Teil dieses Workflows — aber das Beleg-Format muss dafür prüfbar sein.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/sim.sh` | Einziger Ort der Änderung. `cmd_test` (Z. 216) fährt heute schon einen UI-Test im Simulator; `run_xcodebuild` schreibt die Rohausgabe nach `$SESSION_DERIVED_DATA/xcodebuild.log`, aber ohne `-resultBundlePath` — der `.xcresult`-Pfad steht nur im Log. Rückgabewert-Falle: Pipe durch `tee`/`xcbeautify`, `set -eo pipefail` fängt es nur dank `pipefail` (vgl. `signed_build` Z. 285: PIPESTATUS-Fehler aus #144). |
| `LooseEndsUITests/*.swift` | Fünf UI-Testklassen; vier hängen Screenshots per `XCTAttachment(screenshot:)` an (`CaptureSmokeTests:83`, `RecognitionWalkthroughTests:83`, `ContextUniquenessTests:20`, `SpeechListeningTests:19`). Kein Test schreibt Dateien direkt — Screenshots existieren nur im `.xcresult`. |
| `.claude/active_workflow` (Worktree) | Enthält den Namen des aktiven Workflows → daraus `docs/artifacts/<name>/`. |
| `/Users/hem/Developer/loose-ends/.claude/workflows/<name>.json` | Workflow-State liegt im **Haupt-Checkout**, nicht im Worktree; direkter Zugriff ist durch `bash_gate.py` gesperrt („Direct state file manipulation"), nur über `workflow.py`. |
| Plugin `core/hooks/workflow.py` | `VALID_ARTIFACT_TYPES` (Z. 269) kennt kein `simulator_run`; Gate `phase8_complete` (Z. 1006) prüft nur Adversary-Verdict + Dialog-Nachweis. Ändern = Schnitt 2. |
| Plugin `core/hooks/adversary_dialog.py` | **Vorbild für das Format:** Block `## Geprüfte Dateien` mit Zeilen `- sha256:<hex>  <pfad>` (Z. 572–660), `stamp` schreibt sie, `_verify_examined_file_hashes` gleicht gegen Ist-Stand ab, `phase8_code_files` (Z. 933 ff.) bestimmt die seit Basis (`merge-base origin/main HEAD`) geänderten Code-Dateien. |
| `docs/project/04-stand.md` Z. 135–150 | Beschreibt Stufe 2 als „build, launch, screenshot" — Schnitt 3, nicht hier. |

## Existing Patterns
- **Simulator-Belege bisher von Hand zusammengestellt:** #144 legte `test-green-simulator.txt` (kopierte
  sim.sh-Ausgabe) und `screenshots/` (per `xcresulttool export attachments`, mit `manifest.json`) ab und
  registrierte sie als `test_output` mit Freitext-Beschreibung. #157 analog (`ui-test-output.txt`,
  `upgrade-durchlauf/`). Genau diese Handarbeit soll ein Befehl ersetzen.
- **Screenshot-Export:** `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`
  liefert PNGs + `manifest.json` (`suggestedHumanReadableName`, `timestamp`, `deviceName`). War in #153
  schon in `sim.sh` gebaut, ging aber mit dem Rückbau (#161) nicht auf `main`.
- **Prüfsummen-Belege:** Adversary-Dialog-Stempel (siehe oben); #144 `korpus-messung.md` führte
  Prüfsummen des gemessenen Codes von Hand.
- **Simulator-Lock** (`acquire_lock`), Session-DerivedData, Destination über `sim_id()` — wiederverwenden.

## Dependencies
- Upstream: `xcodebuild test`, `xcrun xcresulttool` (`get test-report`/`export attachments`), `git`
  (`rev-parse HEAD`, `merge-base origin/main HEAD`, `diff --name-only`), `shasum -a 256`, `python3`.
- Downstream: Schnitt 2 (Plugin-Gate) liest `simulator-run.txt`; Schnitt 3 (Doku) beschreibt den Befehl;
  #144 sollte laut Henning der erste echte Fall durchs Gate sein — ist aber bereits `phase8_complete`
  (2026-09-28), d. h. der „scharfe Fall" muss ein anderes Ticket werden (DoD: „ein echtes Ticket ist einmal
  vollständig durch das neue Gate gelaufen").
- Verwandt: #143 (Gerätestufe belegt nur Start), #153/#161 (Rückbau der Geräte-UI-Läufe).

## Existing Specs
- `docs/specs/**/feat-153-geraetestufe-ui-test*` und `docs/context/feat-153-geraetestufe-ui-test.md` —
  enthielt xcresult-Export und Screenshot-Ablage, Lehren daraus (Zeile 49 nennt #145 als Voraussetzung).

## Risks & Considerations
- **„Nicht von Hand erzeugbar" ist in Schnitt 1 allein nicht erreichbar.** Eine Textdatei kann jeder
  schreiben. Fälschungsfest wird es nur, wenn der Beleg auf etwas verweist, das das Gate selbst
  nachprüfen kann: der `.xcresult`-Bundle (von `xcodebuild` erzeugt, enthält Testergebnis, Zeit, Gerät)
  mit seiner Prüfsumme, und Prüfsummen der Produktionsdateien, die gegen den Ist-Stand gerechnet werden.
  Das Format muss das in Schnitt 1 schon hergeben. Ergänzend denkbar: Write/Edit-Sperre auf
  `simulator-run.txt` per Hook (Schnitt 2).
- **Welcher Ablauf „gehört zum Ticket"?** Ohne Zuordnung könnte ein beliebiger, immer grüner UI-Test
  (z. B. `CaptureSmokeTests`) den Beleg liefern. Mindestens: Testklasse ist Pflichtargument und steht im
  Beleg; ob das Gate prüft, dass sie zu den geänderten Dateien/zur Spec passt, ist eine Analysefrage.
- **Welche Dateien sind „Produktionsdateien"?** Kandidat: dieselbe Menge wie `phase8_code_files` (seit
  `merge-base origin/main`), gefiltert auf Produktpfade (`LooseEnds/`, `Shared/`, `LooseEnds*/`, ohne
  Tests/Docs/Measurement). Muss mit Schnitt 2 übereinstimmen, sonst passen die Prüfsummen nie.
- **Uncommittete Änderungen:** Lauf auf schmutzigem Arbeitsstand → `HEAD` passt nicht zum getesteten
  Code. Prüfsummen über Dateiinhalt (nicht Commit) fangen das ab; `HEAD` allein reicht nicht.
- **Projekt veraltet:** Ohne `generate` fehlen neue Dateien im Build (CLAUDE.md) — der Befehl sollte vor
  dem Lauf generieren, sonst belegt er einen alten Stand.
- **Rückgabewerte in Pipes** (PIPESTATUS-Lehre #144) und **`xcodebuild.log` wird von jedem Lauf
  überschrieben** (Memory „Unit-Lauf-Eigenheiten") — Beleg muss aus dem eigenen Lauf schreiben, nicht aus
  einem später gelesenen Log.
- **Worktree vs. Haupt-Checkout:** Artefakte in `docs/artifacts/<wf>/` im Worktree, State im Haupt-Checkout;
  Registrierung nur über `workflow.py add-artifact` (bash_gate).
- **Kein Simulator-Pfad der Geräteliste:** `scripts/sim.sh` steht nicht in der Geräte-Pfadliste → Abnahme
  endet nach Stufe 2.
- **Alternative zum Plugin-Gate:** Eine repo-eigene Prüfung (CI-Schritt oder Pre-Push) gegen denselben Beleg
  griffe auch ohne aktiven Workflow — Frage für `/20-analyse` bzw. Schnitt 2.

## Analysis

### Type
Feature (Werkzeug/Abnahme-Infrastruktur, keine sichtbare App-Änderung → keine Entwurfsvorschau nötig)

### Recherche (2026-10-01)
- `xcresulttool get test-results summary` ist seit Xcode 16 der Ersatz für das abgekündigte
  `get --format json` (Apple-Forum 763888, 763050). Lokal mit Xcode 27.0 (27A266a) an einem echten
  LooseEnds-Bündel geprüft: JSON enthält `result` ("Passed"/"Failed"), `startTime`/`finishTime` (Unix),
  `passedTests`/`failedTests`/`skippedTests`/`totalTestCount`, `devicesAndConfigurations[].device`
  (`deviceName`, `osVersion`, `platform`), `testFailures[]`. Schema-Version 0.4.0.
- `xcresulttool export attachments --path X --output-path D [--test-id] [--filter "*.png"]` schreibt
  Dateien + `manifest.json` (lokale `--help`, Xcode 27).
- `.xcresult` ist nicht signiert (keine Apple-Quelle zu einer Integritätsprüfung gefunden) — ein Bündel
  ist mit Bash-Zugriff kopier-/fälschbar. Ziel ist, Vergessen und Bequemlichkeit abzufangen, nicht Betrug.

### Plugin-Fakten, die das Format festlegen
- Prüfsummen-Zeilen wie im Adversary-Stempel: `- sha256:<64hex>  <pfad>` unter `## Geprüfte Dateien`,
  Regex `(?m)^-\s*sha256:([0-9a-f]{64})\s+(.+?)\s*$` (`adversary_dialog.py:573`, Abgleich Z. 636–659).
- Dateimenge `phase8_code_files` (`adversary_dialog.py:955–971`): Basis `base_commit` bzw.
  `merge-base origin/main HEAD`; `git diff --name-only --diff-filter=d <basis>` + untracked
  (`ls-files --others --exclude-standard`), gefiltert per `is_gated_code_path` (`hook_utils.py:710`):
  Code-Endung, ausgenommen Pfadkomponenten exakt `Tests`/`UITests`/`docs`/`scripts`/… und
  `.md/.txt/.json/.yml`. **Folge:** `LooseEndsTests/`, `LooseEndsUITests/`, `Measurement/` zählen als
  Code. Das ist gewollt — ändert sich der Test nach dem Lauf, ist der Lauf veraltet.
- `bash_gate.py` lässt Skripte `workflow.py add-artifact` aufrufen; `simulator_run` fehlt in
  `VALID_ARTIFACT_TYPES` (Z. 269) → Registrierung erst mit Schnitt 2; bis dahin als `test_output`.
- `.gitignore:8` ignoriert `*.xcresult`; PNGs in `docs/artifacts/` werden versioniert (25 im Repo).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/sim.sh` | MODIFY | Neuer Befehl `test-proof <Class[/test]>`: immer `generate`, Lock, Boot, `xcodebuild test` mit `-resultBundlePath`, Rückgabewert über PIPESTATUS, ruft danach `sim-proof.py`; Hilfetext. `run_xcodebuild` nur additiv (optionales Ergebnisbündel), `test`/`unit`/`report` unverändert |
| `scripts/sim_proof.py` | CREATE | Beleg erzeugen: summary + Anhänge aus dem Bündel lesen, Code-Dateien wie das Plugin bestimmen, Prüfsummen, `simulator-run.txt` schreiben. Reine Funktionen getrennt von I/O |
| `scripts/test_sim_proof.py` | CREATE | `python3 -m unittest`: summary-Parsing (Passed/Failed/fehlende Felder), Dateifilter (Spiegel von `is_gated_code_path`), Format-Roundtrip gegen den Plugin-Regex, Pfade mit Leerzeichen; Fixture inline |
| `docs/artifacts/<wf>/simulator-run.txt`, `…/simulator-run/` | erzeugt | Beleg, `summary.json`, Screenshots + `manifest.json` (das Bündel selbst bleibt lokal, gitignored) |

### Belegformat (Entwurf)
```
# Simulator-Beleg
erzeugt: 2026-10-01T14:03:11+0200
befehl: scripts/sim.sh test-proof CaptureSmokeTests
workflow: feat-145-simulator-beleg
head: <40hex>
basis: <40hex> (merge-base origin/main HEAD)
testklasse: CaptureSmokeTests
ergebnis: Passed
xcodebuild: ** TEST SUCCEEDED **
tests: 3 gesamt, 3 bestanden, 0 fehlgeschlagen, 0 übersprungen
start: <unix>  ende: <unix>
geraet: iPhone 17, iOS 27.0
summary: docs/artifacts/<wf>/simulator-run/summary.json  sha256:<64hex>
xcresult: <lokaler Pfad>  (gitignored)
screenshots: docs/artifacts/<wf>/simulator-run/*.png (N Stück)

## Geprüfte Dateien
- sha256:<64hex>  LooseEnds/Views/Foo.swift
```

### Scope Assessment
- Files: 3 (+ erzeugte Artefakte)
- Estimated LoC: ~+230 (sim.sh ~+35, sim_proof.py ~+115, Tests ~+80); Tests zählen mit, Grenze 250
- Risk Level: LOW — reines Werkzeug, berührt keine App-Datei; CI ruft `sim.sh` nicht auf (`ci.yml` nutzt
  `xcodebuild` direkt). „Kein Pfad der Geräteliste berührt."

### Technical Approach (Empfehlung)
Eigenes Python-Hilfsskript statt Heredoc, damit es per `unittest` testbar ist und `sim.sh` dünn bleibt.
Getroffene technische Entscheidungen:
1. **`generate` läuft immer vorher** — sonst belegt der Lauf einen alten Projektstand.
2. **Roter Test schreibt trotzdem einen Beleg** (`ergebnis: Failed`), Befehl endet mit Fehler; ein alter
   grüner Beleg wird vorher gelöscht. So unterscheidet das Gate „nie gelaufen" von „rot gelaufen".
3. **Bündel lokal, Auszug versioniert:** `.xcresult` bleibt gitignored; `summary.json` (aus dem Bündel
   exportiert) und Screenshots liegen versioniert im Artefaktordner, der Beleg trägt die Prüfsumme der
   `summary.json`. Schnitt 2 kann so ohne Bündel prüfen, mit Bündel zusätzlich nachlesen.
4. **Dateimenge = Obermenge der Plugin-Menge** (merge-base; das Skript kennt `base_commit` nicht).
   Schnitt 2 prüft „jede vom Gate berechnete Datei steht im Beleg und der Hash stimmt", nicht Gleichheit.
5. **Testklasse ist Pflichtargument** und steht im Beleg. Ob sie zum Ticket passt, prüft Schnitt 2 bzw.
   der Adversary — nicht maschinell in Schnitt 1.
Abnahme: echter Lauf mit grüner Klasse (Beleg + Screenshot da) und ein bewusst roter Lauf (Beleg
`Failed`, Exit ≠ 0).

### Alternativen
- **A. Nur das `.xcresult` als Beleg, keine Textdatei:** nichts Handschreibbares, aber HEAD und
  Prüfsummen fehlen, und das Bündel ist gitignored. Taugt nicht als Beleg im Repo.
- **B. Prüfung als CI-Schritt statt Plugin-Gate:** griffe auch ohne Workflow, aber CI sieht den lokalen
  Simulatorlauf nicht. Höchstens als Ergänzung (Beleg-Format prüfen), nicht als Ersatz.
- **C. Beleg-Erzeugung ins Plugin verlegen (generisch für alle Projekte):** der Agent hätte keinen
  Schreibweg zur Datei, das wäre das stärkste Gate. Kostet: Plugin müsste `xcodebuild` kennen, das die
  Hooks bewusst sperren, und die Drei-Schnitt-Aufteilung aus #145 kippt. Zielbild für später, nicht jetzt.
- **D. Hook-Sperre ergänzen (Schnitt 2):** Write/Edit auf `simulator-run.txt` verbieten — billig, schließt
  den bequemsten Fälschungsweg.

### Dependencies
`xcodebuild`, `xcrun xcresulttool` (Xcode 27), `git`, `python3` (nur stdlib), `shasum`. Downstream:
Schnitt 2 (Plugin) liest Format und Regex; Schnitt 3 (Doku 04-stand.md).

### Open Questions
- keine PO-Fragen. Technisch offen für Schnitt 2: Drift zwischen Filter-Spiegel und `is_gated_code_path`
  (dort per Test absichern).
