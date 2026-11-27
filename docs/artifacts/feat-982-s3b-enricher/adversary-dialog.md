# Adversary Dialog — feat-982-s3b-enricher
Spec: docs/specs/enrichment/feat-982-schnitt-3b-enricher-aus-release.md
Datum: 2026-11-27 21:59

## Checkliste
- [x] **AC-1:** `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher` und `EnrichmentParsing` sind in `Shared/Enrichment/FoundationModelsEnricher.swift` außerhalb des `#if` definiert und stehen nicht mehr in `Shared/Enrichment/EnrichmentDraft.swift`; dort bleiben `EnrichmentDraft` und `Guess` (Test 1).
- [x] **AC-2:** In `project.yml` schließen die Targets `LooseEndsWidgets`, `LooseEndsShare` und `LooseEndsWatch` `Enrichment/FoundationModelsEnricher.swift` aus (bestehende excludes bleiben), und `LooseEnds` setzt `EXCLUDED_SOURCE_FILE_NAMES: FoundationModelsEnricher.swift` nur in der Konfiguration Release; `LooseEndsLab` listet die Datei weiter (Test 1).
- [x] **AC-3:** `.github/workflows/ci.yml` enthält den Schritt „Diagnose model availability“ nicht mehr (Test 1).
- [x] **AC-4:** `.github/workflows/testflight.yml` enthält im iOS- und im macOS-Job eine Archivprüfung, die bei einem Symbol `FoundationModelsEnricher` (`nm`) oder einer gelinkten `FoundationModels` (`otool -L`) in einer Hauptbinärdatei von App oder Erweiterung mit `::error::` abbricht (Test 1).
- [x] **AC-5:** Der Kommentar zu `selfConsistencyValues` in `EnrichmentDraft.swift` verweist nicht mehr auf eine nicht vorhandene Stelle in `MeasurementRun.swift` (Durchsicht des Diffs, Test 1 prüft die Abwesenheit des alten Wortlauts).
- [x] **AC-6:** Im Release-Simulatorbau der iOS-App tragen Haupt-App, Widgets-appex und Share-appex weder ein Symbol `FoundationModelsEnricher` noch eine Bindung an `FoundationModels`; der Debug-Bau enthält das Symbol weiter (Tests 3, 4).
- [x] **AC-7:** `./scripts/sim.sh generate`, `./scripts/sim.sh build` und `./scripts/sim.sh unit` sind grün; Messtests und Labor-Ziel kompilieren, `RuleGoldenTests` laufen ohne Änderung an `rule-golden.json` (Tests 2, 6).
- [x] **AC-8:** Im Simulator wird „Vor Konzert“ erfasst und steht mit Titel „Vor Konzert“ und ohne Dauer in der Liste (`./scripts/sim.sh test-proof NoModelCaptureTests`, Test 5).
- [x] **AC-9:** `CLAUDE.md` enthält den Satz „until S3“ nicht mehr und sagt unter „No model, no New“ und `Shared/Enrichment`: Release-Bauten ohne Modell, Debug-Testhost und Labor-App mit (Durchsicht des Diffs).

## Dialog

### Runde 1
**Adversary:** Alle Punkte einzeln gegen Code und Artefakte geprueft.
- AC-1: Typen stehen in FoundationModelsEnricher.swift vor dem `#if` (Zeile 4-38, `#if` erst Zeile 40); EnrichmentDraft.swift enthaelt nur noch EnrichmentDraft/Guess. Grep ueber Shared, LooseEnds, Watch, Widgets, Share: kein Produktfile ausser dem Adapter nennt EnrichmentInput/Example/TaskEnricher/EnrichmentParsing/FoundationModelsEnricher.
- AC-2: project.yml Zeile 146 (Watch), 235 (Widgets), 269 (Share) schliessen aus, Zeile 136 EXCLUDED_SOURCE_FILE_NAMES nur unter configs.Release, Zeile 305 Lab listet die Datei. Alte Excludes (CaptureTextIntent, NextUpWidgetIntents) stehen weiter.
- AC-3: grep -c "Diagnose model" ci.yml = 0; yaml.safe_load beider Workflows ok, Nachbarschritt "Show crash and failure details" vollstaendig.
- AC-4: Schritt in upload (Zeile 347) und upload-mac (584). Beide Skripte per yaml extrahiert, bash -n ok, gegen Fake-Archive gelaufen: Pfad mit Leerzeichen ("My Loose Ends.app"), Release-Binaer exit 0, Debug-dylib exit 1 mit ::error::, gestrippte Debug-dylib (nm 17 Treffer, otool-Link 1) exit 1, macOS-Layout (Contents/MacOS) mit echtem Mac-Release-Bau exit 0, leeres Archiv exit 1 (Beleg binary-check.txt). grep ohne Treffer unter set -e/pipefail: `|| true` faengt es, Ergebnis "0". Verschachtelte Watch-App (Watch/LooseEndsWatch.app, PlugIns/*.appex) wird von find -type d erfasst.
- AC-5: alter Wortlaut ("three targets", "No product code calls it" in alter Form) weg; neuer Kommentar nennt LooseEndsLab/MeasurementRunner und MeasurementRunTests; grep bestaetigt genau diese zwei Nutzer ausser der Definition.
- AC-6: Eigene Pruefung der Release-Produkte (Binaer 21:56, nach letzter Quellaenderung 21:43): LooseEnds, Widgets, Share, Watch, WatchWidgets: nm=0, otool-L=0, strings=0; keine debug.dylib. Gegenprobe Debug: nm 42, Link 1.
- AC-7: test-run-output.txt: xcresult 1380 bestanden/0 fehlgeschlagen/12 uebersprungen, XCTest 104/0, test_modell_rest_entfernt 13 OK. Eigener Lauf: `./scripts/sim.sh generate` hinterlaesst keinen Unterschied im git status; test_info_plist_sync.py und test_entitlements_sync.py je 4 Tests OK. rule-golden.json nicht in git diff --stat. Uebersprungene (12) sind vorbestehende Messtests/Sprache de_DE (Log nennt textform-run.json fehlt, Latenzschutz Sprache nicht unterstuetzt), nicht dieser Schnitt.
- AC-8: simulator-run.txt Passed 1/1, Head 4cc271f. Screenshot 1 (Detail): Titel "Vor Konzert", Text "Nothing new found.", Zeile "+ Duration", keine Dauer, keine KI-Marke. Screenshot 2: "All open" zeigt viermal "Vor Konzert".
- AC-9: "until S3" nicht mehr in CLAUDE.md; beide Stellen (Zeile 97 und Shared/Enrichment-Absatz) aktualisiert.
- Scope: 6 Dateien im Diff, davon App-Code 2 Swift + project.yml; Swift-Zeilen ca. 60 verschoben/geaendert, weit unter 250.
- Zusatz Mac-Release: xcodebuild Release generic/platform=macOS (derivedDataPath im Scratchpad, Sperre per mkdir gehalten und freigegeben) BUILD SUCCEEDED, FoundationModelsEnricher.swift nicht im Log (0), LooseEnds.app und LooseEndsWidgets.appex nm=0 link=0, Archivskript exit 0.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gezielt Randfaelle gesucht.
- Viermal "Vor Konzert": Test NoModelCaptureTests startet die echte App ohne --ui-testing mit echtem Store und ohne Aufraeumen (setUp nur continueAfterFailure; letzter Aenderungscommit der Testdatei 6c87205, nicht in diesem Diff). Jeder Lauf legt eine Aufgabe an, Reste frueherer Laeufe im selben Simulator. Vorbestand des Tests, kein Defekt dieses Schnitts; Titelerhalt und fehlende Dauer im Detail-Screenshot sind davon unberuehrt (Befund F001, LOW).
- Archivpruefung prueft nur Hauptbinaeren, nicht eingebettete Frameworks/dylibs: laut Spec so gefordert, im Release gibt es keine debug.dylib; Hinweis, kein Verstoss.
- Release-Binaer vor Quellaenderung gebaut? Nein, Zeitstempel 21:56 nach 21:43; Lab-Ziel Debug-Build SUCCEEDED mit Symbol (33).
- Mac-Release wirklich ohne Adapter: ja (siehe oben); iOS-Release-Bau mit Share/Widgets: ja.
- Kein Gegenbeispiel gefunden, das ein AC bricht.
**Implementierer:** (nicht beteiligt)

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/NoModelCaptureTests.swift:11
  Description: Der Test legt in der echten App ohne Aufraeumen jedes Mal eine Aufgabe "Vor Konzert" an; der Listen-Screenshot zeigt deshalb vier gleiche Zeilen.
  Spec requirement: AC-8 - Aufgabe steht mit Titel "Vor Konzert" und ohne Dauer in der Liste
  Conflict: Keiner fuer diesen Schnitt, Vorbestand; AC-8 bleibt erfuellt (Detail zeigt Titel, keine Dauer).
  Remediation: Optional eigenes Ticket: Test raeumt vorher auf oder deinstalliert die App.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/FoundationModelsEnricher.swift:4
  Evidence: Typen vor dem #if (Zeile 40); EnrichmentDraft.swift ohne sie.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: project.yml:136
  Evidence: Release-only Exclude; Excludes Zeile 146/235/269, Lab Zeile 305.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: .github/workflows/ci.yml:271
  Evidence: Schritt entfernt, YAML parst, Nachbarschritt intakt.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: .github/workflows/testflight.yml:347
  Evidence: Skripte (347 und 584) gegen Fake-Archive und echten Mac-Release-Bau getestet, siehe Runde 1.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: Shared/Enrichment/EnrichmentDraft.swift:32
  Evidence: Neuer Kommentar nennt reale Nutzer (MeasurementRunner, MeasurementRunTests).
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: project.yml:136
  Evidence: Eigene nm/otool/strings-Pruefung: 0 in allen Release-Binaeren.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: project.yml:305
  Evidence: Testlauf 1380/0/12, XCTest 104/0, generate ohne Diff, Sync-Tests OK, Lab baut.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: LooseEndsUITests/NoModelCaptureTests.swift:9
  Evidence: Passed 1/1, Screenshots geoeffnet und beschrieben.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: CLAUDE.md:97
  Evidence: "until S3" weg, beide Stellen aktualisiert.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 1380 passed, 0 failed, 12 übersprungen (vorbestehend, benannt: Messberichte ohne Rohdatei, Sprachlatenz de_DE); XCTest 104/0
Edge cases: Archivskript gegen Leerzeichen, macOS-Layout, gestrippt, leer, grep ohne Treffer geprüft; Mac-Release gebaut
Regressions: None found
Checklist: 9/9 points proven (F001 LOW, Vorbestand)

## Geprüfte Dateien

- sha256:b76d950d80319eb294cbf2205e42e42e2e68337cdc1cdefee82f0dd51b3e5646  .github/workflows/ci.yml
- sha256:32d140c7c6c0fb12826971a136703fee29a9a25de06d3c06f97027a3fc27aa2b  .github/workflows/testflight.yml
- sha256:0a8dc4d2d04db335e233353470ea1cc5d3185e926b8f23279d5eb690f2565808  CLAUDE.md
- sha256:ef79c58b387c5d94c02169bef92016baec8547944e0331912076a75238bb76dc  LooseEndsUITests/NoModelCaptureTests.swift
- sha256:4714a6803fa49de573e0e3867a577d3e93487906e18643f5e0b3328fcf825db7  Shared/Enrichment/EnrichmentDraft.swift
- sha256:cd906bc585ebc3a02e60e56eb685dcb6ed9e78d3f5a0b5867b79bbccf10e3659  Shared/Enrichment/FoundationModelsEnricher.swift
- sha256:5918e734b8ef4086bdad89f02a70bd6a4ea549b685fcc371c7ea612d9375d5ff  project.yml

## Prüfbasis

- base: ac5ef8685e07e2afa56d09767e0963f802c26d92
- blob:1d1f7929db337f11b29be2ba59b8e35c2b25254e  .github/workflows/ci.yml
- blob:e2645cccb231cdbd15f17d5a0853d5e9f6685b2a  .github/workflows/testflight.yml
- blob:d402dbdfca1636a8e19dbd044a54cc3848a14b5a  CLAUDE.md
- blob:769867558e508c4c857521ccaa2395240181a07d  LooseEndsUITests/NoModelCaptureTests.swift
- blob:9f9d7db0ff9f379e6c94b48cab9f55bb2f7af37a  Shared/Enrichment/EnrichmentDraft.swift
- blob:689a56a1fd77f5e9a2e74b00825885931eabe10d  Shared/Enrichment/FoundationModelsEnricher.swift
- blob:ae246c3a516c629389108600f5307af916130510  project.yml
