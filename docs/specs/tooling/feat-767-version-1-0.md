---
entity_id: feat-767-version-1-0
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: feat-767-version-1-0
---

# Spec: #767 Version 1.0 für die App-Store-Einreichung: eine Quelle für die Versionsnummer, Build mit 1.0 hochladen

## Approval

- [ ] Approved

## Purpose

In App Store Connect wartet die App-Store-Version 1.0 auf einen Build. Alle bisherigen Builds tragen die Version 0.1.0, deshalb ist
keiner auswählbar (Apple ordnet einen Build nur zu, wenn `CFBundleShortVersionString` der App-Store-Version gleicht; Erweiterungen
tragen dieselbe Version wie die App). Henning wollte wissen, ob es „vielleicht 1.1“ sein müsse: nein. Es gibt keine veröffentlichte
1.0, die vorbereitete App-Store-Version heißt 1.0, und 1.0 ist größer als 0.1.0. Der abgelaufene TestFlight-Build „1.0 (1)“ stört
nicht: Innerhalb einer Version muss nur die Buildnummer neu und höher sein, und sie ist die Lauf-Nummer (über 125).

Die Spec macht zwei Dinge: `MARKETING_VERSION` in `project.yml` wird `"1.0"`, und die beiden Archivprüfungen in `testflight.yml` tragen
die Version nicht mehr als Literal, sondern lesen sie aus `project.yml`. Damit gibt es genau eine Quelle, und der nächste Versionssprung
(1.0.1, 1.1) ist eine Zeile.

Ohne Modell: Konfigurationswert und Shell-Auslese, kein Modellweg.

## Source

- **Quelle der Version:** `project.yml:24` `MARKETING_VERSION: "0.1.0"`. Alle Ziele (App, Watch, Widgets, Watch-Widgets, Teilen,
  Labor) lesen `$(MARKETING_VERSION)` (`CFBundleShortVersionString`, `project.yml` Z. 76, 152, 191, 228, 259, 310).
- **Doppelpflege heute:** `.github/workflows/testflight.yml:148` (iOS-Archivprüfung) und `:423` (macOS-Archivprüfung) setzen
  `MARKETING="0.1.0"` fest und vergleichen jede Bundle-Version mit `$MARKETING ($BUILD)`; Kommentar Z. 6 „tag like v0.1.0“.
- **Doku:** `docs/reference/testflight.md` Z. ~288 (Quelle `MARKETING_VERSION`) und Z. ~292 (erwartete Version `0.1.0 (<Lauf-Nummer>)`).
- **Unberührt:** `Shared/Services/AppVersion.swift` und `LooseEndsTests/AppVersionTests.swift` zeigen die Version nur an (Test mit
  festem Beispielwert); `scripts/test_info_plist_sync.py` sieht nur die Variable, keinen Diff.
- **Beleg Apple:** Build-Version gleich App-Store-Version, Erweiterungen dieselbe Version (Apple-Forum 730234).
- **Identifier:** keiner neu. Neue Datei `scripts/test_marketing_version.py`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| Apple-Regel Build-Version == App-Store-Version | Vorgabe | Version muss exakt `1.0` heißen, wie in App Store Connect |
| `github.run_number` | Workflow | Buildnummer, läuft weiter, kein Konflikt |
| `scripts/test_asc_wait_build.py` | Test | prüft `bash -n` je Block von `testflight.yml`; muss grün bleiben |
| Beide Jobs `upload` und `upload-mac` | Workflow | checken das Repo aus, Arbeitsordner ist die Wurzel, `project.yml` liegt dort; lokal (`ARCHIVE=… BUILD=…`) ebenso aus der Wurzel |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| project.yml | MODIFY | `MARKETING_VERSION: "0.1.0"` → `"1.0"` |
| .github/workflows/testflight.yml | MODIFY | beide Archivprüfungen lesen `MARKETING` aus `project.yml` und brechen ab, wenn leer; Kommentar Z. 6 `v0.1.0` → `v1.0` |
| scripts/test_marketing_version.py | CREATE | Tests: Version ist 1.0, kein Versions-Literal in `testflight.yml`, Auslese-Befehl liefert den Wert aus `project.yml`, leerer Wert bricht ab |
| docs/reference/testflight.md | MODIFY | erwartete Version `1.0 (<Lauf-Nummer>)`; Hinweis, dass die Archivprüfung die Version aus `project.yml` liest |

### Estimated Changes

4 Dateien, ca. +45/−5 LoC. Funktionen ≤ 50 LoC.
**Berührt die Geräteliste:** `project.yml` steht dort (Signierung, Berechtigungen, Targets). Stufe 3 ist damit Pflicht und läuft über
TestFlight (siehe Abnahme).

## Implementation Details

### 1. `project.yml`

Z. 24: `MARKETING_VERSION: "1.0"`. Schreibweise exakt `1.0`, zwei Teile, wie in App Store Connect. Sonst nichts in der Datei.

### 2. `testflight.yml`

In beiden Prüf-Schritten ersetzt diese Zeile das Literal (nach `BUILD="${BUILD:?…}"`):

```bash
MARKETING=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"$/\1/p' project.yml)
[ -n "$MARKETING" ] || { echo "::error::MARKETING_VERSION not found in project.yml"; exit 1; }
```

Beide Jobs laufen aus der Repo-Wurzel; ein lokaler Lauf (`ARCHIVE=… BUILD=… bash …`) ebenfalls. Der Vergleich
`[ "$ver" = "$MARKETING ($BUILD)" ]` (iOS) und `need CFBundleShortVersionString "$MARKETING"` (macOS) bleibt unverändert. Kommentar Z. 6:
„push a tag like v1.0“.

### 3. Test `scripts/test_marketing_version.py`

`unittest`, ohne Netz, liest die echten Dateien. Den Auslese-Befehl nimmt der Test aus `testflight.yml` (die Zeile, die mit
`MARKETING=$(sed` beginnt), damit er genau das prüft, was läuft.

### 4. Doku

`docs/reference/testflight.md`: „Version `1.0 (<Lauf-Nummer>)`“; im Absatz „Was der Workflow tut“ der Zusatz, dass beide Archivprüfungen die
Version aus `project.yml` (`MARKETING_VERSION`) lesen und nichts mehr fest eingetragen ist.

## Alternativen

- **Version in `project.yml` ändern und die beiden Literale mitziehen** (3 Zeilen, kleinster Schnitt). Verworfen: Die Doppelpflege ist
  genau die Falle, die beim nächsten Versionssprung (1.0.1, 1.1) wieder zuschlägt; vergessen heißt: Archivprüfung stoppt den Upload.
  Gekippt wird dafür nichts außer der bisherigen Gewohnheit, die Version in der Prüfung zu duplizieren.
- **`agvtool` oder `xcodebuild -showBuildSettings` im Prüfschritt.** Verworfen: langsamer, braucht das erzeugte Projekt und einen
  Xcode-Aufruf zwischen Archiv und Upload; `project.yml` ist die Quelle (CLAUDE.md: Projekt ist generiert, `project.yml` führt). Würde
  den Grundsatz „Prüfung liest nur Dateien des Archivs und der Quelle“ aufgeben.
- **Version 1.1 statt 1.0.** Verworfen: Die vorbereitete App-Store-Version heißt 1.0; 1.1 ließe sich ihr nicht zuordnen.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests

`python3 -m unittest discover -s scripts` (die CI ruft denselben Lauf); die neue Datei gezielt: `python3 scripts/test_marketing_version.py`.

- [ ] `test_marketing_version_is_1_0`: `project.yml` enthält genau eine Zeile `MARKETING_VERSION:` und ihr Wert ist `"1.0"`.
- [ ] `test_no_version_literal_in_workflow`: `testflight.yml` enthält kein `MARKETING="<Ziffern…>"`-Literal mehr (Regex `MARKETING="[0-9]`).
- [ ] `test_workflow_reads_version_from_project_yml`: beide Prüf-Schritte enthalten die Auslesezeile; `bash` führt sie gegen das echte
  `project.yml` aus und liefert genau `1.0`; gegen eine Temp-Kopie mit `MARKETING_VERSION: "2.3.4"` genau `2.3.4`.
- [ ] `test_empty_version_aborts`: Temp-Kopie ohne `MARKETING_VERSION`-Zeile → der Prüfblock (Auslese plus Abbruchzeile) endet mit Exit ≠ 0
  und der Ausgabe `::error::MARKETING_VERSION not found`.
- [ ] Bestehend, unverändert grün: `scripts/test_asc_wait_build.py` (`bash -n` je Block von `testflight.yml`, Tabelle per `tee`).
- [ ] Gesamtlauf `python3 -m unittest discover -s scripts` grün (auch `test_info_plist_sync.py`, `test_ci_xcode27.py`).

### Simulator (Stufe 2)

`./scripts/sim.sh generate`, `build`, `launch`, `screenshot`: Einstellungen zeigen „Version 1.0“. Kein Gerät.

### Nach dem Merge (Stufe 3 über TestFlight)

Manueller TestFlight-Lauf auf `main` mit deutschem `what_to_test`. Kein Lauf auf Hennings Geräten, keine Aktion ohne sein Wort.

## Acceptance Criteria

- **AC-1:** `project.yml` setzt `MARKETING_VERSION` auf `"1.0"`; es gibt genau eine solche Zeile. Geprüft durch
  `test_marketing_version_is_1_0`.
- **AC-2:** `testflight.yml` trägt kein Versions-Literal (`MARKETING="<Ziffern>"`) mehr; beide Archivprüfungen (iOS, macOS) lesen
  `MARKETING` aus `project.yml`. Geprüft durch `test_no_version_literal_in_workflow` und `test_workflow_reads_version_from_project_yml`.
- **AC-3:** Der in `testflight.yml` stehende Auslese-Befehl liefert, in bash ausgeführt, genau den Wert aus `project.yml` (echte Datei:
  `1.0`; Temp-Kopie mit anderem Wert: dieser Wert). Geprüft durch `test_workflow_reads_version_from_project_yml`.
- **AC-4:** Fehlt der Wert oder ist er leer, bricht der Prüfblock mit Exit ≠ 0 und `::error::MARKETING_VERSION not found in project.yml`
  ab, der Upload findet nicht statt. Geprüft durch `test_empty_version_aborts`.
- **AC-5:** `scripts/test_asc_wait_build.py` bleibt grün (jeder Block von `testflight.yml` besteht `bash -n`), und
  `python3 -m unittest discover -s scripts` ist grün. Geprüft durch diesen Lauf.
- **AC-6:** `docs/reference/testflight.md` nennt die erwartete Version `1.0 (<Lauf-Nummer>)` und dass die Archivprüfung sie aus
  `project.yml` liest; `0.1.0` steht dort nicht mehr als erwartete Version. Geprüft durch Lesen der Datei im Diff und
  `grep -n "0\.1\.0" docs/reference/testflight.md` (kein Treffer als erwartete Version).
- **AC-7:** Simulator-Stufe: Die frisch generierte App baut, und die Einstellungen zeigen Version 1.0. Nachweis: Screenshot per
  `./scripts/sim.sh screenshot`, geöffnet und beschrieben.
- **AC-8:** Stufe 3 über TestFlight (nach Merge): Der manuelle Lauf auf `main` mit deutschem `what_to_test` ist grün, beide Archivprüfungen
  (iOS und macOS) melden `1.0 (<Lauf-Nummer>)` in der Tabelle der Lauf-Zusammenfassung, und der Build erscheint in App Store Connect unter
  Version 1.0 und ist dort der App-Store-Version 1.0 zuordenbar. Nachweis: Lauf-Link, Ausschnitt der Archivprüfung, App-Store-Connect-Abfrage
  (`asc_wait_build`-Ausgabe oder Probe).

Umfang (höchstens die vier Dateien der Tabelle, ±250 LoC) ist ein Gate der Definition of Done, kein AC.

## Out of Scope

- **Einreichung zur App-Prüfung** und **externe Beta-Einreichung** für den neuen Versionszug 1.0: nur auf Hennings ausdrückliches Wort.
  Der neue Versionszug braucht bei Apple vermutlich erneut eine Beta-Prüfung, bevor er extern verteilt wird (bisher Build 125 unter 0.1.0).
- **Auswahl des Builds in der App-Store-Version** in App Store Connect und alles weitere dort (Texte, Bilder, Preise).
- **Buildnummern-Schema:** bleibt `github.run_number`.
- **Änderungen an App-Code,** `AppVersion.swift`, Info.plist, Entitlements, CloudKit-Schema.
- **Test auf Hennings Geräten:** nichts; Stufe 3 läuft über TestFlight nach seinem Zeitplan.

## Definition of Done

- [ ] Änderungen in den vier Dateien per PR gemergt (`Closes #767`); AC-1 bis AC-7 erfüllt.
- [ ] Gate: `python3 -m unittest discover -s scripts` grün; `git diff --stat` zeigt höchstens die vier Dateien der Tabelle, ±250 LoC.
- [ ] Simulator-Beleg (AC-7) als Screenshot geöffnet und beschrieben.
- [ ] Nach dem Merge: manueller TestFlight-Lauf mit deutschem `what_to_test`; AC-8 belegt (Lauf grün, Archivprüfung `1.0 (N)` für iOS und
  macOS, Build unter Version 1.0 in App Store Connect). Henning bekommt die Buildnummer in Alltagssprache; er wählt den Build in der
  App-Store-Version selbst oder gibt das Wort dafür.
- [ ] Ticket erst schließen, wenn AC-8 belegt ist.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Versionsnummer und Quelle einer Konfigurationszeile; keine Produktarchitektur, kein App-Code, keine Änderung an einer ADR.

## Changelog

- 2026-10-30: Initial spec created
