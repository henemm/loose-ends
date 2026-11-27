# Kontext: feat-982-s3b-enricher (#982 Schnitt 3b)

## Request Summary

#982 S3b, der letzte offene Schnitt (Issue-Kommentar 2026-11-27 17:10 UTC): Der Modellcode
(`FoundationModelsEnricher` samt Naht `TaskEnricher`) wird seit S1 im Produkt nicht mehr aufgerufen,
liegt aber weiter im App-Target und damit in jedem TestFlight- und App-Store-Bau. Ziel: Der ausgelieferte
Bau (Release) enthält und linkt das Modell nicht mehr; Labor-App und Messtests behalten es (ADR-22,
CLAUDE.md „No model, no New“: „the model code stays compiled only for the lab app and measurement tests until S3“).

Gerätefeedback zu Build 145 (Gerätepunkte #982 S1 / #1000): im Issue keine Rückmeldung (Stand 2026-11-27 21:35 MEZ).

## Related Files

| Datei | Rolle |
|---|---|
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Modell-Adapter (`#if canImport(FoundationModels) && !os(watchOS)`), `ModelEnrichment` (@Generable) |
| `Shared/Enrichment/EnrichmentDraft.swift` | `EnrichmentDraft` + `Guess` (von 9 Regeldateien benutzt, 28 Stellen), dazu nur-Modell: `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`, `EnrichmentParsing` |
| `project.yml` | Target `LooseEnds` (sources `LooseEnds`, `Shared`), `LooseEndsLab` listet beide Enrichment-Dateien einzeln, `LooseEndsTests` hängt per `@testable import LooseEnds` am App-Modul |
| `.github/workflows/ci.yml` (Z. 274–287) | toter Schritt „Diagnose model availability“: sucht Logzeilen „Model unavailable“/„Enriched“, die seit S1 niemand mehr schreibt |
| `.github/workflows/testflight.yml` (Z. 129 ff.) | `xcodebuild archive` = Release; Archivprüfungen ab Z. 145 |
| `CLAUDE.md` | „No model, no New“, „Where things live“ `Shared/Enrichment` |
| Tests mit Modellbezug | `RealModelTests`, `RealModelLatencyTests`, `RealModelGuardrailTests`, `TitleFidelityPromptTests`, `ModelSeamTests`, `ModelPromptLanguagesTests`, `MeasurementRunTests`, `EnrichmentTests` (`EnrichmentParsing`) – alle Debug, `@testable import LooseEnds` |

Produktcode, der die Modelltypen nennt: keiner außer den Regeln mit `EnrichmentDraft.Guess`
(`ContextWordRule`, `DueDateRule`, `DurationRule`, `ImportanceUrgencyRule`, `PlaceWordRule`, `ProjectNameRule`, `RecognitionRule`).
`LooseEnds/` importiert `FoundationModels` nirgends; `Measurement/` nennt keine der Modelltypen (nur `LanguageModelError` zur Fehlerklasse).

## Existing Patterns

- Lab-Target listet Einzeldateien aus `Shared/` (`path: Shared/Enrichment/...`).
- Konfigurationsabhängiges in `project.yml` über `settings.configs` bzw. `[config=…]`-Schlüssel.
- Archivprüfungen in `testflight.yml` brechen mit `::error::` ab (SDK, dSYM, Privacy-Strings).

## Analyse: Wege

1. **Empfohlen – Release schließt die Modelldateien aus.** Nur-Modell-Typen aus `EnrichmentDraft.swift`
   in `FoundationModelsEnricher.swift` verschieben; im Target `LooseEnds`
   `EXCLUDED_SOURCE_FILE_NAMES[config=Release]: FoundationModelsEnricher.swift`. `EnrichmentDraft` mit `Guess`
   bleibt (reiner Datentyp der Regeln, ruft nichts). Debug (Testhost, `sim.sh real-model`) behält das Modell,
   Labor-App unverändert. Archivprüfung: Hauptbinärdatei linkt `FoundationModels` nicht (`otool -L`).
   Toter CI-Diagnoseschritt entfällt. ~5 Dateien, wenig App-LoC.
2. **Alternative – eigenes Messtest-Target.** Modelldateien und `RealModel*`-Tests in ein Target ohne
   App-Modul (`LooseEndsModelTests`) mit eigenen Kopien von `Enums.swift`; App enthält das Modell in keiner
   Konfiguration. Sauberer, aber die Tests benutzen App-Typen (Regeln, `Importance`) → doppelte Typen,
   viele Testdateien, sprengt 4–5 Dateien/250 LoC.
3. **Alternative – nichts tun.** S3b schließen als „nicht nötig“: kein Produktpfad ruft das Modell
   (S1). Fiele: der ADR-22-Satz „compiled only for the lab app and measurement tests“ bliebe unerfüllt,
   und der Release-Bau linkt `FoundationModels` weiter.

`Guess` in einen eigenen Typ `RuleGuess` umbenennen wäre ebenfalls möglich, berührt aber 9 Regeldateien
ohne Verhaltensgewinn → nicht in diesem Schnitt.

## Dependencies / Dependents

- Release-Archiv (TestFlight, App Store) – nur dort wirkt der Ausschluss; lokal belegbar mit einem
  Release-Simulatorbau.
- watchOS-Target kompiliert `Shared/` ebenfalls; der Enricher ist dort per `#if !os(watchOS)` schon draußen.

## Risks

- Release-Bau bricht, wenn irgendein Produktfile einen der verschobenen Typen nennt → Release-Simulatorbau als Beleg.
- `project.yml` steht auf der Geräteliste → Stufe 3 über TestFlight (Start der App, Erfassung) im nächsten Bau.
- Datenschutztext nennt Apple Intelligence noch (de/en, Website) – Änderung nur nach Hennings Freigabe;
  eigener Folgeschritt, nicht in diesem Schnitt.

## Analysis

**Type:** Feature (Aufräumen, kein sichtbares Verhalten)

**Neuer Befund:** `FoundationModelsEnricher.swift` steckt nicht nur in der App, sondern über `Shared/` auch in
Widgets und Teilen-Erweiterung (iOS, `canImport(FoundationModels)` wahr). Die Watch schließt ihn per `#if !os(watchOS)` aus.

### Affected Files

| Datei | Change | Grund |
|---|---|---|
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | nur-Modell-Typen (`EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`, `EnrichmentParsing`) heraus; `EnrichmentDraft` + `Guess` bleiben |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | nimmt die Typen auf, `import Foundation` vor das `#if` |
| `project.yml` | MODIFY | Widgets, Share, Watch: `excludes: Enrichment/FoundationModelsEnricher.swift`; LooseEnds: `configs: Release: EXCLUDED_SOURCE_FILE_NAMES: FoundationModelsEnricher.swift` |
| `.github/workflows/testflight.yml` | MODIFY | Archivprüfung: kein Symbol `FoundationModelsEnricher` (`nm`) in App und Erweiterungen, kein `FoundationModels` (`otool -L`) |
| `.github/workflows/ci.yml` | MODIFY | toter Schritt „Diagnose model availability“ entfällt |
| `scripts/test_modell_rest_entfernt.py` | MODIFY (Test) | neue Prüfungen: Ausschlüsse in `project.yml`, Typen verschoben, CI-Schritt weg, Archivprüfung vorhanden |
| `CLAUDE.md` | MODIFY (Doku) | „No model, no New“ / `Shared/Enrichment`: Modell nur in Debug, Labor-App, Messtests |

### Scope / Risk
App-Code: 2 Swift-Dateien, ~+35/−35 (Verschiebung); dazu Konfiguration/CI ~+30. Risiko niedrig–mittel:
Release-Bau ist die einzige Stelle, an der der Ausschluss wirkt → lokaler Release-Simulatorbau mit `nm`/`otool` als Beleg.
`project.yml` auf der Geräteliste → Stufe 3 über TestFlight (App startet, Erfassung, Widget, Teilen).

### Technical Approach (Variante A, Plan-Agent bestätigt)
RED: `scripts/test_modell_rest_entfernt.py` erweitern → rot. GREEN: Typen verschieben, `project.yml`, CI-Schritt
raus, Archivprüfung, Doku. Beleg: `sim.sh generate`, `sim.sh unit` (Debug, Messtests kompilieren), Release-Simulatorbau
→ `nm` ohne `FoundationModelsEnricher`, `otool -L` ohne `FoundationModels` für App, Widgets, Share.
Verworfen: B (ohne Typverschiebung, bricht Release), C (`#if DEBUG`, Labor-App baut Release mit und bräche),
eigenes Messtest-Target (doppelte Typen, sprengt Umfang), nichts tun (ADR-22-Satz bliebe unerfüllt).
Recherche: `EXCLUDED_SOURCE_FILE_NAMES` filtert die Compile-Sources-Phase nach Dateinamen
(https://davedelong.com/blog/2018/07/25/conditional-compilation-in-swift-part-2/).

### Open Questions
Keine für diesen Schnitt. Folgefrage an Henning (eigener Schritt, nicht hier): Datenschutztext ohne Apple-Intelligence-Absatz.
