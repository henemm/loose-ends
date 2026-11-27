---
entity_id: feat-982-schnitt-3b-enricher-aus-release
type: refactor
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: feat-982-s3b-enricher
---

# Spec: Modelladapter aus dem Release-Bau, Schnitt 3b (Feature #982, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#982 (Epic #999), letzter Schnitt. Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“
Entscheidung: ADR-22 (`docs/project/00-entscheidungen.md`): das On-Device-Modell verlässt den Produktweg. Schnitt 1, 2 und
3a sind ausgeliefert. CLAUDE.md sagt: „the model code stays compiled only for the lab app and the measurement tests until S3“.
Dieser Schnitt erfüllt den Satz.

## Purpose

Kein Produktcode ruft das Modell auf, aber `FoundationModelsEnricher` steckt weiter in jedem ausgelieferten Bau: nicht nur in der
App, sondern über `Shared/` auch in Widgets und Teilen-Erweiterung (iOS, `canImport(FoundationModels)` ist dort wahr). Nach diesem
Schnitt enthalten Release-Bauten (App iOS/macOS, Widgets, Teilen-Erweiterung, Watch) den Adapter nicht und linken
`FoundationModels` nicht. Debug (Testhost für Messtests, `sim.sh real-model`) und die Labor-App behalten ihn. Kein sichtbares
Verhalten ändert sich.

## Nicht in diesem Schnitt

- Datenschutztext, der Apple Intelligence noch nennt: nur nach Hennings Freigabe, eigener Schritt.
- Umbenennung `EnrichmentDraft.Guess` (berührt 9 Regeldateien ohne Verhaltensgewinn).
- Eigenes Messtest-Target (siehe Alternative 1).
- Gerätepunkte von #982 S1 und #1000 (Build 145): bleiben in deren Definition of Done.

## Alternativen

Rules-before-model: Dieser Schnitt entfernt Modellcode, er führt keinen ein; der Satz „Without the model this fails because …“
entfällt, weil das Modell keine Aufgabe übernimmt.

1. **Eigenes Messtest-Target** (`LooseEndsModelTests` ohne App-Modul, Modelldateien und `RealModel*`-Tests dorthin). Das App-Modul
   enthielte das Modell in keiner Konfiguration. Verworfen: Die Tests benutzen App-Typen (Regeln, `Importance`), das gäbe doppelte
   Typen und viele verschobene Testdateien, sprengt 4–5 Dateien und ±250 LoC. Kippt keine ADR; bliebe ein späterer Schritt.
2. **Nichts tun, S3b als „nicht nötig“ schließen.** Kein Produktpfad ruft das Modell. Verworfen: Der ADR-22-Satz „compiled only
   for the lab app and measurement tests“ bliebe unerfüllt, `FoundationModels` würde weiter gelinkt. Kippt nichts, lässt ADR-22
   aber unvollständig umgesetzt.
3. **Ohne Typverschiebung nur ausschließen (B).** Verworfen: `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`,
   `EnrichmentParsing` stehen in `EnrichmentDraft.swift`; der Release-Bau bräche mit fehlenden Typen.
4. **`#if DEBUG` um den Adapter (C).** Verworfen: Die Labor-App baut Release mit und bräche. Die Konfiguration entscheidet in
   `project.yml`, nicht der Compilerschalter.
5. **Modelltests und Labor-App löschen.** Widerspricht der Definition of Done von #982 („Messcode bleibt“), bräuchte Hennings
   Entscheidung. Würde ADR-22 insofern ändern, als Messbarkeit entfiele. Verworfen.

Gewählt: Variante A (Release schließt die Modelldatei aus, Typen verschoben).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22 (keine neue ADR)
- **Rationale:** Setzt die bestehende Entscheidung „kein Modell im Produkt“ im ausgelieferten Bau um. Die gewählte Variante
  kippt keine ADR.

## Source

- **File:** `Shared/Enrichment/FoundationModelsEnricher.swift`
- **Identifier:** `FoundationModelsEnricher`, `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`, `EnrichmentParsing`
  (aus `Shared/Enrichment/EnrichmentDraft.swift` hierher); Ausschlüsse in `project.yml`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `EnrichmentDraft` / `Guess` | module | Bleibt in `EnrichmentDraft.swift`; sieben Regeln benutzen `Guess` (ContextWordRule, DueDateRule, DurationRule, ImportanceUrgencyRule, PlaceWordRule, ProjectNameRule, RecognitionRule) |
| `LooseEndsLab` (project.yml) | target | Listet beide Enrichment-Dateien einzeln; bleibt unverändert und baut weiter mit dem Adapter |
| `LooseEndsTests` | target | `@testable import LooseEnds`, Debug-Testhost; Messtests (`RealModel*`, `TitleFidelityPromptTests`, `ModelSeamTests`, `ModelPromptLanguagesTests`, `MeasurementRunTests`, `EnrichmentTests`) brauchen den Adapter im Debug-Bau |
| `scripts/sim.sh` | script | `generate`, `unit`, `build`, `test-proof`, `real-model` |
| `.github/workflows/testflight.yml` | workflow | Archiv = Release; bekommt die Archivprüfung |
| `.github/workflows/ci.yml` | workflow | Verliert den toten Schritt „Diagnose model availability“ |

## Scope

### Affected Files

| Datei | Change | Was |
|---|---|---|
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`, `EnrichmentParsing` heraus; `EnrichmentDraft` + `Guess` bleiben; veralteten Kommentar zu `selfConsistencyValues`/`MeasurementRun.swift` korrigieren |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | nimmt die vier Typen außerhalb des `#if` auf, `import Foundation` vor das `#if` |
| `project.yml` | MODIFY | `LooseEndsWidgets`, `LooseEndsShare`, `LooseEndsWatch`: `excludes: Enrichment/FoundationModelsEnricher.swift` (bestehende excludes bleiben); `LooseEnds`: `settings.configs.Release.EXCLUDED_SOURCE_FILE_NAMES: FoundationModelsEnricher.swift` |
| `.github/workflows/testflight.yml` | MODIFY | Archivprüfung in iOS- und macOS-Job |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Diagnose model availability“ entfällt |
| `CLAUDE.md` | MODIFY (Doku) | Satz „until S3“ und Eintrag `Shared/Enrichment` auf den neuen Stand |
| `scripts/test_modell_rest_entfernt.py` | MODIFY (Test) | neue Prüfungen (AC-1 bis AC-5) |

### Estimated Changes

- App-Code (zählt): 2 Swift-Dateien, etwa 70 LoC Verschiebung (+35/−35), keine neue Logik.
- Dazu Konfiguration und Doku: `project.yml`, zwei Workflows, `CLAUDE.md`; Test: ein Skript.
- Gesamt 7 Dateien, davon 2 App-Code; innerhalb von ±250 LoC App-Code.

## Implementation Details

Reihenfolge: zuerst `scripts/test_modell_rest_entfernt.py` erweitern und rot laufen lassen (TDD RED). Dann:

1. Die vier Typen samt Kommentaren aus `EnrichmentDraft.swift` nach `FoundationModelsEnricher.swift` verschieben, hinter
   `import Foundation`, vor und außerhalb von `#if canImport(FoundationModels) && !os(watchOS)`. Vorher per grep belegen,
   dass kein Produktfile außer dem Adapter und den Messtests die Typen nennt (Kontext: nur die Regeln mit `Guess`).
2. `project.yml`: Ausschluss je Target; das Release-Setting nur im Target `LooseEnds`. Gemeint ist der Dateiname, nicht der
   Pfad (`EXCLUDED_SOURCE_FILE_NAMES` filtert die Compile-Sources-Phase nach Dateinamen). `./scripts/sim.sh generate`.
3. Archivprüfung in `testflight.yml` (iOS- und macOS-Job, neben den bestehenden Archivprüfungen): für jede Mach-O-
   Hauptbinärdatei der App und ihrer Erweiterungen im Archiv gilt: zeigt `nm` ein Symbol mit `FoundationModelsEnricher` oder
   listet `otool -L` `FoundationModels`, endet der Lauf mit `::error::`. Die Schleife nimmt die Binärdateien aus den
   `Info.plist`-Einträgen (`CFBundleExecutable`) der Bundles, nicht aus einer festen Liste.
4. Toten CI-Schritt entfernen, `CLAUDE.md` anpassen.

Debug bleibt unverändert: Der Testhost braucht den Adapter für `@testable import LooseEnds`. Die Labor-App bindet die
Dateien selbst ein und ist vom Release-Ausschluss des Targets `LooseEnds` nicht betroffen.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN den Repo-Stand vor der Umsetzung WHEN `python3 scripts/test_modell_rest_entfernt.py` läuft THEN schlägt er
  fehl (Typen noch in `EnrichmentDraft.swift`, keine Ausschlüsse, CI-Schritt da, Archivprüfung fehlt); nach der Umsetzung besteht er.
- [ ] Test 2: GIVEN den Stand nach der Umsetzung WHEN `./scripts/sim.sh generate` und `./scripts/sim.sh unit` laufen THEN sind alle
  Unit-Tests grün, einschließlich der Kompilierung der Messtests und `RuleGoldenTests` ohne Auffrischen.
- [ ] Test 3: GIVEN einen Release-Simulatorbau der iOS-App WHEN `nm` und `otool -L` auf Haupt-App, Widgets-appex und Share-appex
  laufen THEN zeigt keines ein Symbol `FoundationModelsEnricher` und keines listet `FoundationModels`.
- [ ] Test 4: GIVEN den Debug-Bau der App WHEN `nm` läuft THEN enthält er `FoundationModelsEnricher` weiterhin (Gegenprobe,
  damit Test 3 nicht an einem leeren Bau scheitert oder besteht).
- [ ] Test 5: GIVEN den Simulator WHEN `./scripts/sim.sh test-proof NoModelCaptureTests` läuft (echte Verdrahtung ohne
  `--ui-testing`, erfasst „Vor Konzert“, prüft Titel und fehlende Dauer) THEN steht die Aufgabe mit Titel „Vor Konzert“ ohne
  Dauer in der Liste; Belegdatei und Screenshots werden geöffnet und beschrieben.
- [ ] Test 6: GIVEN `./scripts/sim.sh build` und das Labor-Ziel WHEN sie bauen THEN sind beide grün (Labor-App behält den Adapter).

## Acceptance Criteria

- **AC-1:** `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher` und `EnrichmentParsing` sind in
  `Shared/Enrichment/FoundationModelsEnricher.swift` außerhalb des `#if` definiert und stehen nicht mehr in
  `Shared/Enrichment/EnrichmentDraft.swift`; dort bleiben `EnrichmentDraft` und `Guess` (Test 1).
- **AC-2:** In `project.yml` schließen die Targets `LooseEndsWidgets`, `LooseEndsShare` und `LooseEndsWatch`
  `Enrichment/FoundationModelsEnricher.swift` aus (bestehende excludes bleiben), und `LooseEnds` setzt
  `EXCLUDED_SOURCE_FILE_NAMES: FoundationModelsEnricher.swift` nur in der Konfiguration Release; `LooseEndsLab` listet
  die Datei weiter (Test 1).
- **AC-3:** `.github/workflows/ci.yml` enthält den Schritt „Diagnose model availability“ nicht mehr (Test 1).
- **AC-4:** `.github/workflows/testflight.yml` enthält im iOS- und im macOS-Job eine Archivprüfung, die bei einem Symbol
  `FoundationModelsEnricher` (`nm`) oder einer gelinkten `FoundationModels` (`otool -L`) in einer Hauptbinärdatei von App oder
  Erweiterung mit `::error::` abbricht (Test 1).
- **AC-5:** Der Kommentar zu `selfConsistencyValues` in `EnrichmentDraft.swift` verweist nicht mehr auf eine nicht
  vorhandene Stelle in `MeasurementRun.swift` (Durchsicht des Diffs, Test 1 prüft die Abwesenheit des alten Wortlauts).
- **AC-6:** Im Release-Simulatorbau der iOS-App tragen Haupt-App, Widgets-appex und Share-appex weder ein Symbol
  `FoundationModelsEnricher` noch eine Bindung an `FoundationModels`; der Debug-Bau enthält das Symbol weiter (Tests 3, 4).
- **AC-7:** `./scripts/sim.sh generate`, `./scripts/sim.sh build` und `./scripts/sim.sh unit` sind grün; Messtests und
  Labor-Ziel kompilieren, `RuleGoldenTests` laufen ohne Änderung an `rule-golden.json` (Tests 2, 6).
- **AC-8:** Im Simulator wird „Vor Konzert“ erfasst und steht mit Titel „Vor Konzert“ und ohne Dauer in der Liste
  (`./scripts/sim.sh test-proof NoModelCaptureTests`, Test 5).
- **AC-9:** `CLAUDE.md` enthält den Satz „until S3“ nicht mehr und sagt unter „No model, no New“ und `Shared/Enrichment`:
  Release-Bauten ohne Modell, Debug-Testhost und Labor-App mit (Durchsicht des Diffs).

## Risiken

- **Release-Bau bricht,** wenn ein Produktfile einen der verschobenen Typen nennt: Release-Simulatorbau ist der Beleg (Test 3).
- **Ausschluss wirkt nur im Release;** lokal ist der Release-Simulatorbau der einzige Nachweis vor dem Archiv, die Archivprüfung
  sichert den Weg danach. Sie läuft erst im nächsten TestFlight-Lauf; sie wird beim Bau gegen ein lokales Archiv-Muster
  (Bundle-Schleife) geprüft, soweit ohne Signierung möglich.
- **Watch** schließt den Adapter per `#if !os(watchOS)` schon aus; der zusätzliche Ausschluss ist Absicherung, kein Verhaltenswechsel.
- **Generiertes Projekt:** nach Änderung an `project.yml` `./scripts/sim.sh generate`, der CI-Schritt „Generate leaves the tree clean“ muss grün bleiben.
- **Hotspot `CLAUDE.md` und `project.yml`:** vor dem PR `main` einarbeiten und offene PRs auf Konflikte prüfen.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`), Release-Simulatorbau mit `nm`/`otool -L` belegt
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`), `RuleGoldenTests` unverändert
- [ ] `python3 scripts/test_modell_rest_entfernt.py` grün
- [ ] UI-Tests grün (CI); Simulatorbeleg über `./scripts/sim.sh test-proof NoModelCaptureTests`
- [ ] Gerätestufe: `project.yml` steht auf der Geräteliste, Stufe 3 ist Pflicht und läuft über TestFlight: In der normalen
  App startet die App, Erfassung funktioniert, das Widget zeigt Aufgaben, Teilen von außen funktioniert wie zuvor. Henning
  bekommt das in einfachen Worten, nichts auf seinen Geräten ohne sein „jetzt ist ein Test möglich“; bis seine Rückmeldung
  da ist, bleibt #982 offen (PR mit `Refs #982`). Kein AC der Spec.
- [ ] Die Archivprüfung zeigt im ersten TestFlight-Lauf nach dem Merge „grün“ (Lauf wird von Claude nachgesehen)
- [ ] Ausgeliefert: PR, CI grün, gemergt; GitHub-Board aktuell

## Changelog

- 2026-11-27: Initial spec created
