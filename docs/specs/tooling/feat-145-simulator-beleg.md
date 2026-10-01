---
entity_id: feat-145-simulator-beleg
type: feature
created: 2026-10-01
updated: 2026-10-01
status: draft
workflow: feat-145-simulator-beleg
---

# Spec: #145 Schnitt 1 — `sim.sh test-proof` erzeugt den Simulator-Beleg maschinell

## Approval

- [ ] Approved

## Purpose

`scripts/sim.sh` bekommt den Befehl `test-proof <Testklasse[/test]>`. Er spielt die angegebene UI-Testklasse im
Simulator durch und schreibt aus dem eigenen Lauf einen Beleg `docs/artifacts/<workflow>/simulator-run.txt`
samt `summary.json` und Screenshots, mit Prüfsummen der seit der Basis geänderten Code-Dateien. Damit
entsteht der Nachweis „die App wurde benutzt" aus einem echten Lauf und nicht mehr aus handkopierter
Ausgabe (#144, #157).

### Abgrenzung

- **Schnitt 1 (diese Spec):** Befehl, Belegformat, Tests des Hilfsskripts. Alles im Projekt-Repo.
- **Schnitt 2 (nicht Scope, Plugin-Repo):** Gate vor `phase8_complete`, neuer Artefakttyp `simulator_run`
  (fehlt heute in `VALID_ARTIFACT_TYPES`), Schreibsperre auf `simulator-run.txt` per Hook. Das Format
  hier muss dafür maschinell prüfbar sein (Regex, Prüfsummen, Ergebnisfeld), das Gate selbst wird nicht gebaut.
- **Schnitt 3 (nicht Scope):** Beschreibung in `docs/project/04-stand.md` und `CLAUDE.md`.

Bis Schnitt 2 steht, wird der Beleg als `test_output` registriert.

### Bekannte Grenze (offen benannt)

Absolut fälschungssicher ist auf derselben Maschine nichts: Wer vollen Shell-Zugriff hat (der Agent),
kommt an jeden Schlüssel, den das Werkzeug lesen kann. Das `.xcresult` ist nicht signiert. Das Ziel
(Tech-Lead-Entscheidung 2026-10-01 auf PO-Nachfrage) ist deshalb: **Fälschen ist aufwendiger als der ehrliche
Lauf und fällt auf.** Dafür liefert Schnitt 1 die Grundlage, Schnitt 2 die Prüfung:

1. **Bündel bleibt neben dem Beleg** (`docs/artifacts/<wf>/simulator-run/run.xcresult`, gitignored), nicht
   im Session-DerivedData. So kann Schnitt 2 `summary.json` und `ergebnis` aus dem Original-Bündel neu
   ableiten und vergleichen. Eine Fälschung müsste ein vollständiges Xcode-Ergebnisbündel nachbauen.
2. **Schreibsperre** auf `simulator-run.txt` und `simulator-run/` per Hook (Schnitt 2).
3. **Prüfsummen gegen den Ist-Stand** (diese Spec): Code-Änderung nach dem Lauf entwertet den Beleg.

Nicht gewählt: Signatur (Schlüssel wäre für den Agenten lesbar, kein Gewinn); das Gate fährt den Lauf
selbst (stärkste Stufe, kostet Minuten je Abschluss und einen Plugin-Umbau, Zielbild für später).

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `cmd_test` (Zeile ~216) als Vorbild, `run_xcodebuild`, `acquire_lock`, `sim_id()`, `signed_build` (PIPESTATUS-Muster, #144)
- **File:** `scripts/sim_proof.py` (neu)
- **File:** `scripts/test_sim_proof.py` (neu)
- **Plugin-Vorbild (nur gelesen, nicht geändert):** `adversary_dialog.py:573` (Prüfsummen-Regex), `adversary_dialog.py:955–971` (`phase8_code_files`), `hook_utils.py:710` (`is_gated_code_path`)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `xcodebuild test -resultBundlePath` | Upstream | Testlauf und Ergebnisbündel |
| `xcrun xcresulttool get test-results summary`, `export attachments` | Upstream (Xcode 27) | Ergebnis (`result`, Zahlen, Zeiten, Gerät) und Screenshots aus dem Bündel |
| `git` (`rev-parse HEAD`, `merge-base origin/main HEAD`, `diff --name-only --diff-filter=d`, `ls-files --others --exclude-standard`) | Upstream | Basis und Dateimenge |
| `shasum -a 256` bzw. Python `hashlib` | Upstream | Prüfsummen |
| `python3` (nur Standardbibliothek) | Upstream | Hilfsskript, `unittest` |
| `.claude/active_workflow` im Worktree | Upstream | Name des aktiven Workflows → Artefaktordner |
| Schnitt 2 (Plugin-Gate) | Downstream | Liest Format und Regex |

## Scope

### Affected Files

| File | Change Type | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | Neuer Befehl `test-proof`, Hilfetext; `run_xcodebuild` nur additiv um ein optionales Ergebnisbündel erweitert. `test`, `unit`, `report`, `build` bleiben im Verhalten unverändert |
| `scripts/sim_proof.py` | CREATE | Beleg erzeugen. Reine Funktionen (summary parsen, Dateien filtern, Beleg formatieren) getrennt von I/O (git, xcresulttool, Dateien) |
| `scripts/test_sim_proof.py` | CREATE | `python3 -m unittest scripts/test_sim_proof.py`, Fixtures inline |
| `docs/artifacts/<wf>/simulator-run.txt`, `docs/artifacts/<wf>/simulator-run/` | erzeugt | Beleg, `summary.json`, Screenshots, `manifest.json`. Das `.xcresult` bleibt lokal (gitignored, `.gitignore:8`) |

### Estimated Changes

- 3 Dateien, ~+245 LoC (`sim.sh` ~+35, `sim_proof.py` ~+110, Tests ~+100 inkl. Fehlerfall-Tests). Knapp
  innerhalb der Grenze von 250 LoC; wird sie beim Bau überschritten, wird vor dem Weiterbauen gestoppt.
- Risiko LOW: reines Werkzeug, keine App-Datei, keine sichtbare UI (keine Entwurfsvorschau nötig). CI
  ruft `sim.sh` nicht auf (`ci.yml` nutzt `xcodebuild` direkt).
- Abnahme: „Kein Pfad der Geräteliste berührt." Stufe 2 ist hier der echte Lauf von `test-proof` selbst.

## Implementation Details

### Aufruf

```
scripts/sim.sh test-proof <Testklasse>[/<test>]
```

Beispiel: `scripts/sim.sh test-proof CaptureSmokeTests`.

- **Testklasse ist Pflichtargument.** Fehlt es: Fehlermeldung mit Aufrufmuster auf stderr, Exit ≠ 0, kein
  Lauf, kein Beleg, ein vorhandener alter Beleg bleibt unberührt.
- **Kein aktiver Workflow** (`.claude/active_workflow` fehlt oder leer): klare Fehlermeldung
  („Kein aktiver Workflow, Beleg hätte keinen Ablageort"), Exit ≠ 0, kein Lauf.

### Ablauf in `sim.sh`

1. Argument und aktiven Workflow prüfen (siehe oben). Artefaktordner `docs/artifacts/<wf>/` anlegen.
2. **Alten Beleg löschen** (`simulator-run.txt` und `simulator-run/`), bevor irgendetwas läuft. Ein
   früherer grüner Beleg darf nie neben einem späteren, gescheiterten Lauf stehen bleiben.
3. **`generate` läuft immer** (Entscheidung 1), danach Lock (`acquire_lock`), Simulator bestimmen (`sim_id()`), Boot.
4. `xcodebuild test` für Scheme und `-only-testing:LooseEndsUITests/<Klasse>` mit eigenem
   `-resultBundlePath docs/artifacts/<wf>/simulator-run/run.xcresult` (gitignored über `*.xcresult`,
   bleibt für die Nachprüfung durch Schnitt 2 liegen; Schritt 2 löscht es mit dem alten Beleg). Rückgabewert über `PIPESTATUS` bzw. `pipefail` festhalten
   (Lehre #144), bevor irgendein weiterer Befehl läuft.
5. `python3 scripts/sim_proof.py` aufrufen mit: Workflow, Testklasse, Pfad des Bündels, wörtlicher
   xcodebuild-Endzeile (`** TEST SUCCEEDED **` bzw. `** TEST FAILED **`), Befehlszeile, xcodebuild-Exitcode.
   Der Beleg entsteht aus **diesem** Lauf (Bündel und Rückgabewert), nicht aus einem später gelesenen
   `xcodebuild.log`, das jeder Folgelauf überschreibt.
6. Exitcode von `test-proof` = Exitcode von xcodebuild, sonst der des Hilfsskripts. Roter Lauf:
   Beleg wird trotzdem geschrieben (`ergebnis: Failed`), Exit ≠ 0 (Entscheidung 2).

### `scripts/sim_proof.py`

- **summary:** `xcrun xcresulttool get test-results summary --path <xcresult> --compact` lesen, nach
  `summary.json` speichern. Felder: `result`, `startTime`, `finishTime`, `totalTestCount`,
  `passedTests`, `failedTests`, `skippedTests`, `devicesAndConfigurations[0].device`
  (`deviceName`, `osVersion`). Fehlende Felder führen **nicht** zum Absturz und nicht zu erfundenen
  Werten: `ergebnis` wird dann `Unbekannt`, fehlende Zahlen/Zeiten stehen als `unbekannt`, Exit ≠ 0.
  Ein Beleg mit `ergebnis: Passed` entsteht nur, wenn `result == "Passed"` **und** xcodebuild-Exitcode 0 **und** `totalTestCount ≥ 1`.
- **Screenshots:** `xcrun xcresulttool export attachments --path <xcresult> --output-path docs/artifacts/<wf>/simulator-run/ --filter "*.png"`
  (liefert PNGs und `manifest.json`). Ein grüner Lauf ohne mindestens einen Screenshot ist **kein** gültiger
  Beleg: `ergebnis` bleibt wahrheitsgemäß `Passed`, der Befehl endet aber mit Fehler und Hinweis
  „Testklasse liefert keinen Screenshot" (Beleg ohne `screenshots:`-Zeile mit Anzahl ≥ 1 ist für Schnitt 2 ungültig).
- **Dateimenge:** Basis = `git merge-base origin/main HEAD`. Menge = `git diff --name-only --diff-filter=d <basis>`
  plus `git ls-files --others --exclude-standard`, gefiltert wie `is_gated_code_path` im Plugin
  (Spiegel, siehe nächster Absatz), sortiert, ohne Duplikate. Pfade mit Leerzeichen bleiben erhalten
  (kein Zerlegen an Leerzeichen, `-z`-Ausgabe von git oder zeilenweise ohne `split()`).
- **Filter (Spiegel von `is_gated_code_path`):** Code-Endung gilt, ausgenommen Pfadkomponenten exakt
  `Tests`, `UITests`, `docs`, `scripts` u. ä. wie im Plugin sowie die Endungen `.md`, `.txt`, `.json`, `.yml`.
  **Folge:** `LooseEndsTests/`, `LooseEndsUITests/` und `Measurement/` zählen als Code. Das ist gewollt:
  ändert sich ein Test nach dem Lauf, ist der Lauf veraltet. Beim Bau liest der Implementierer
  `hook_utils.py:710` und bildet die Regel 1:1 nach; die Spiegelung wird im Skript-Kopf mit Verweis auf
  die Plugin-Stelle kommentiert, damit Drift auffällt.
- **Prüfsummen:** SHA-256 über den **Dateiinhalt im Arbeitsverzeichnis** (nicht über den Commit), damit
  uncommittete Änderungen den Beleg entwerten, wenn sie nach dem Lauf entstehen oder davor schon da waren.
- **Schreiben:** Beleg atomar (temporäre Datei, dann umbenennen).

### Belegformat (verbindlich)

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
xcresult: docs/artifacts/<wf>/simulator-run/run.xcresult  (gitignored)
screenshots: docs/artifacts/<wf>/simulator-run/*.png (N Stück)

## Geprüfte Dateien
- sha256:<64hex>  LooseEnds/Views/Foo.swift
```

Regeln:

- `ergebnis:` ist genau eines von `Passed`, `Failed`, `Unbekannt`. Schnitt 2 akzeptiert nur `Passed`.
- Jede Zeile unter `## Geprüfte Dateien` entspricht dem Plugin-Regex
  `(?m)^-\s*sha256:([0-9a-f]{64})\s+(.+?)\s*$`: `- sha256:`, 64 Kleinbuchstaben-Hex, zwei Leerzeichen, Pfad
  relativ zur Repo-Wurzel (Leerzeichen im Pfad erlaubt, keine Anführungszeichen).
- Ist die Dateimenge leer, steht unter der Überschrift genau die Zeile `(keine Code-Dateien geändert)`
  (matcht den Regex nicht, so bleibt „leer" von „vergessen" unterscheidbar).
- Die Prüfsumme der `summary.json` steht im Beleg, damit Schnitt 2 ohne Bündel prüfen kann und mit
  Bündel zusätzlich nachlesen.

### Technische Entscheidungen

1. **`generate` läuft immer vorher.** Ohne `generate` kennt Xcode neue Dateien nicht (siehe `CLAUDE.md`),
   der Lauf belegte sonst einen alten Projektstand.
2. **Roter Lauf schreibt einen Beleg** (`ergebnis: Failed`), der Befehl endet mit Exit ≠ 0, ein alter
   Beleg wird vorher gelöscht. So unterscheidet das Gate „nie gelaufen" von „rot gelaufen".
3. **Bündel lokal, Auszug versioniert:** `.xcresult` bleibt gitignored; `summary.json` und Screenshots
   liegen versioniert im Artefaktordner (PNGs dort sind üblich, 25 im Repo), der Beleg trägt die
   Prüfsumme der `summary.json`.
4. **Dateimenge = Obermenge der Plugin-Menge** (merge-base; das Skript kennt `base_commit` des
   Workflows nicht). Schnitt 2 prüft „jede vom Gate berechnete Datei steht im Beleg und der Hash stimmt",
   nicht Gleichheit.
5. **Testklasse ist Pflichtargument** und steht im Beleg. Ob sie zum Ticket passt, prüft Schnitt 2 bzw.
   der Adversary, nicht Schnitt 1. Ohne diese Zuordnung könnte ein beliebiger, immer grüner Test den
   Beleg liefern: bekanntes Restrisiko, siehe Alternative C.

### Alternativen (nicht gewählt)

- **A. Nur das `.xcresult` als Beleg, keine Textdatei:** nichts Handschreibbares, aber HEAD und
  Prüfsummen fehlen, und das Bündel ist gitignored. Taugt nicht als Beleg im Repo.
- **B. Prüfung als CI-Schritt statt Plugin-Gate:** griffe auch ohne aktiven Workflow, aber CI sieht den
  lokalen Simulatorlauf nicht. Höchstens Ergänzung (Format prüfen), kein Ersatz.
- **C. Beleg-Erzeugung ins Plugin verlegen (generisch für alle Projekte):** der Agent hätte keinen
  Schreibweg zur Datei, das wäre das stärkste Gate. Kostet: Das Plugin müsste `xcodebuild` kennen, das
  die Hooks bewusst sperren, und die Drei-Schnitt-Aufteilung aus #145 kippt. Zielbild für später.
- **D. Hook-Sperre auf `simulator-run.txt` (Schnitt 2):** billig, schließt den bequemsten Fälschungsweg.
  Wird in Schnitt 2 umgesetzt, hier nur als Voraussetzung für „nicht von Hand erzeugbar" benannt.

## Test Plan

### Geplante Tests — Python-Unit-Tests, keine UI-Tests

Das Werkzeug hat keine sichtbare Oberfläche. Die UI-Testklassen der App werden nicht geändert, nur als
Eingabe für die Abnahmeläufe benutzt.

`scripts/test_sim_proof.py` (`python3 -m unittest scripts/test_sim_proof.py`), Fixtures inline:

- **summary-Parsing:** `Passed`-Fixture → `ergebnis Passed`, Zahlen, Gerät, Zeiten; `Failed`-Fixture
  (mit `testFailures`) → `Failed`; Fixture mit fehlenden Feldern (kein `devicesAndConfigurations`, kein
  `finishTime`, kein `totalTestCount`) → kein Absturz, `Unbekannt` bzw. `unbekannt`; `Passed` mit
  xcodebuild-Exitcode ≠ 0 oder `totalTestCount == 0` → nicht `Passed`.
- **Dateifilter (Spiegel):** `LooseEnds/Views/Foo.swift`, `Shared/Services/Bar.swift`,
  `LooseEndsUITests/X.swift`, `LooseEndsTests/Y.swift`, `Measurement/Z.swift`, `project.yml`,
  `LooseEnds/Info.plist` je nach Plugin-Regel drin/draußen; `docs/…`, `scripts/…`, `*.md`, `*.json`, `*.yml`,
  `*.txt` draußen.
- **Format-Roundtrip:** Beleg formatieren, mit dem Plugin-Regex
  `(?m)^-\s*sha256:([0-9a-f]{64})\s+(.+?)\s*$` zurücklesen → exakt dieselben (Hash, Pfad)-Paare; Leer-Fall
  `(keine Code-Dateien geändert)` liefert null Treffer.
- **Pfade mit Leerzeichen:** `LooseEnds/Views/Neue Datei.swift` überlebt Filter, Formatierung und
  Roundtrip unverändert.
- **Fehlerfälle von `sim.sh test-proof` (AC-5), per `subprocess`:** `sim.sh` und ein Stub-Ordner im
  `PATH`, dessen `xcodebuild`/`xcodegen`/`xcrun` nur eine Markerdatei anlegen, in einem temporären
  Repo-Abbild. (a) ohne Argument, (b) mit Argument, aber ohne `.claude/active_workflow` → jeweils Exit ≠ 0,
  Meldung auf stderr enthält das Aufrufmuster bzw. „Kein aktiver Workflow“, Markerdatei existiert nicht
  (kein Lauf), ein vorab angelegter alter Beleg ist in (a) unverändert.

### Abnahmeläufe (Stufe 2, echter Durchlauf)

Werden vom Implementierer selbst als echte Simulatorläufe per Befehl ausgeführt (kein Handtest, nichts für
Henning). Ausgabe wörtlich im Abschlussbericht zitiert (siehe ACs). AC-2 und AC-8 brauchen ein echtes
Ergebnisbündel und echten xcodebuild-Rückgabewert; ein Stub würde genau die Pipe-Falle aus #144 nicht
zeigen. Deshalb sind sie Abnahmeläufe und keine Unit-Tests.

## Acceptance Criteria

- **AC-1:** Grüner Lauf erzeugt Beleg und Screenshot. Given der Simulator ist bereit und
  `.claude/active_workflow` benennt `feat-145-simulator-beleg` / When `scripts/sim.sh test-proof CaptureSmokeTests`
  läuft / Then endet der Befehl mit Exit 0, `docs/artifacts/feat-145-simulator-beleg/simulator-run.txt`
  existiert mit `ergebnis: Passed`, `xcodebuild: ** TEST SUCCEEDED **`, der Klasse und dem HEAD des
  Arbeitsstands, und `simulator-run/` enthält `run.xcresult` (nicht versioniert, `git check-ignore` bestätigt),
  `summary.json` (identisch mit einer frischen `xcresulttool get test-results summary` aus diesem Bündel),
  `manifest.json` und mindestens eine PNG-Datei,
  die geöffnet und beschrieben wird (kein Zählen).
- **AC-2:** Bewusst roter Lauf. Given eine temporär fehlschlagende Testklasse (z. B. ein Aufruf mit
  nicht existierender Klasse oder ein absichtlich roter Test in einer Wegwerf-Kopie, nicht im Commit) /
  When `test-proof` läuft / Then Exit ≠ 0 und, wo ein Bündel entstand, ein Beleg mit `ergebnis: Failed`; ein
  zuvor vorhandener grüner Beleg ist nicht mehr da.
- **AC-3:** Prüfsummen stimmen. Given ein erzeugter Beleg / When für jede Zeile unter
  `## Geprüfte Dateien` `shasum -a 256 <pfad>` ausgeführt wird, und für `summary.json` ebenso / Then stimmt
  jede Prüfsumme mit dem Beleg überein.
- **AC-4:** Format maschinell lesbar. Given der Beleg aus AC-1 / When der Plugin-Regex
  `(?m)^-\s*sha256:([0-9a-f]{64})\s+(.+?)\s*$` darauf angewendet wird / Then liefert er genau die Dateien
  der Menge (merge-base, Code-Filter) und sonst nichts.
- **AC-5:** Fehlerfälle. Given kein Argument / When `scripts/sim.sh test-proof` läuft / Then Fehlermeldung
  mit Aufrufmuster, Exit ≠ 0, kein xcodebuild-Lauf. Given kein aktiver Workflow / When `test-proof X` läuft /
  Then klare Fehlermeldung, Exit ≠ 0, kein Lauf. Automatisch abgedeckt durch die `subprocess`-Tests in
  `scripts/test_sim_proof.py` (siehe Test Plan).
- **AC-6:** Python-Unit-Tests grün. Given `scripts/test_sim_proof.py` / When `python3 -m unittest scripts/test_sim_proof.py`
  läuft / Then alle Tests grün (summary-Parsing, Filter, Roundtrip, Leerzeichen-Pfade, Fehlerfälle von `test-proof`).
- **AC-7:** Bestehende Befehle unverändert. Given der geänderte `sim.sh` / When `./scripts/sim.sh unit`
  und `./scripts/sim.sh build` laufen / Then verhalten sie sich wie vor der Änderung (Unit-Lauf grün,
  Build erfolgreich); `test` und `report` sind im Diff nur dort berührt, wo `run_xcodebuild` additiv
  erweitert wurde.
- **AC-8:** Rückgabewert aus dem eigenen Lauf. Given ein Lauf, dessen xcodebuild-Exitcode ≠ 0 ist, obwohl
  eine nachgeschaltete Pipe-Stufe Exit 0 liefert / When `test-proof` endet / Then ist sein Exitcode ≠ 0
  (PIPESTATUS bzw. `pipefail` wirksam, Lehre #144), nachweisbar am Lauf aus AC-2.

## Risiken

1. **Spiegel des Plugin-Filters driftet.** Ändert das Plugin `is_gated_code_path`, passt die Menge nicht
   mehr. Abfangen in Schnitt 2 durch einen Test dort; hier Kommentar mit Verweis im Skript.
2. **`xcresulttool`-Schema ändert sich** (heute Schema 0.4.0, Xcode 27). Fehlende Felder führen zu
   `Unbekannt` und Exit ≠ 0, nie zu einem grünen Beleg.
3. **Screenshot-Pflicht:** Nicht jede UI-Testklasse hängt Screenshots an (vier von fünf tun es). Für
   eine Klasse ohne Screenshot schlägt `test-proof` mit klarer Meldung fehl, statt einen Beleg ohne
   Sichtnachweis zu liefern.
4. **Schmutziger Arbeitsstand:** `head` allein sagt nichts über uncommittete Änderungen. Deshalb Prüfsummen
   über den Dateiinhalt, nicht über den Commit.
5. **Nicht fälschungssicher** (siehe „Bekannte Grenze"). Wirksam erst mit Schnitt 2.

## Side-Effects

- **Geänderte Dateien:** `scripts/sim.sh`; neu: `scripts/sim_proof.py`, `scripts/test_sim_proof.py`.
- **Erzeugt zur Laufzeit:** `docs/artifacts/<wf>/simulator-run.txt`, `docs/artifacts/<wf>/simulator-run/`.
  Der Befehl löscht dort bei jedem Aufruf zuerst einen vorhandenen Beleg und sein Verzeichnis (nur diese
  beiden Pfade).
- **Neue Permissions (Info.plist)?** Nein. **AppStorage-Keys?** Nein. **Audio-Dateien?** Nein.
- **Keine App-Datei, kein Eintrag der Geräteliste berührt.** Abschlussbericht-Satz: „Kein Pfad der Geräteliste berührt."

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt, jeder Nachweisbefehl ausgeführt, Ausgabe wörtlich im Abschlussbericht, Screenshot angesehen und beschrieben
- [ ] `python3 -m unittest scripts/test_sim_proof.py` grün
- [ ] `./scripts/sim.sh unit` grün, `./scripts/sim.sh build` erfolgreich
- [ ] Echter Lauf `test-proof` mit grüner Klasse (Beleg + Screenshot) und bewusst roter Lauf (Beleg `Failed`, Exit ≠ 0) im Artefaktordner dokumentiert
- [ ] Jeder Commit kompiliert
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] Schnitt 2 und 3 als offene Punkte von #145 sichtbar (Issue bleibt offen, PR verweist mit `Refs #145`, nicht `Closes`)
- [ ] CI grün

## Changelog

- 2026-10-01: Spec aus der Analyse in `docs/context/feat-145-simulator-beleg.md` geschrieben (Schnitt 1 von #145).
