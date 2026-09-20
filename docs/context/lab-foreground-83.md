# Context: Labor-App nur im Vordergrund, Lebenslauf und Fehlerart (#83)

## Request Summary
Die Labor-App (#79) misst im Hintergrund weiter und läuft damit am Akku in Apples Drosselung; sie
schreibt nur Ergebnisse, nicht ihren eigenen Lebenslauf, sodass ein Fehler im Code und eine
Systembedingung in der Datei gleich aussehen. Henning (2026-09-20): „Bist du dir sicher, ob du
zwischen deinen Fehlern und Messwerten unterscheiden kannst?" — Antwort war nein. Umbau: nur im
Vordergrund messen, Bildschirm wach halten, Ereignisse und typisierte Fehlerart mitschreiben,
nach Fehlschlägen warten.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsLab/MeasurementRunner.swift` | Messschleife, Hintergrundlauf (BGContinuedProcessingTask), Anhalteregel, Bedingungen |
| `LooseEndsLab/LabApp.swift` | Oberfläche, Startargument `--measure`, Fußtext mit dem falschen Versprechen „läuft im Hintergrund weiter" |
| `Measurement/MeasurementRun.swift` | Dateiformat (Run, Result, Conditions, Store) — wird um Ereignisse, Fehlerart, Taktregel erweitert |
| `Measurement/Corpus.swift` | Korpus laden; unverändert |
| `LooseEndsTests/DateTitleReportTests.swift` | Bericht aus `Measurement/results/*.json`; zählt nur `succeeded` — Fehlversuche sind schon keine Messwerte |
| `LooseEndsTests/MeasurementRunTests.swift` | Neu (RED): alte Datei lesbar, Ereignisse/Fehlerart Roundtrip, Taktung, Fehlerklassen |
| `project.yml` (Target `LooseEndsLab`) | `UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers` — entfallen |
| `scripts/sim.sh` | `lab`, `lab-fetch`; neu `lab-run [s]` mit Mac-seitigem Start/Stopp-Protokoll |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Wirft `LanguageModelSession.GenerationError` bzw. `LanguageModelError` (iOS 27) — Quelle für die Fehlerart |

## Existing Patterns
- Ergebnisdatei wird nach jedem Satz atomar geschrieben (`MeasurementStore.save`), ISO-8601, sortierte Schlüssel.
- Bedingungen als Klartext-Strings, damit die Datei Enum-Änderungen zwischen iPhone und Mac überlebt — Ereignisse folgen dem gleichen Muster.
- `Corpus.Entry` decodiert fehlende Schlüssel per CodingKeys/Optional — gleicher Weg für `events` (decodeIfPresent).
- Bericht ist ein Test (`DateTitleReportTests`), gerechnet auf dem Mac; `sim.sh report`.
- Bestehende Ergebnisdatei `Measurement/results/date-title.json` (4 Sätze, 3 Fehlversuche vom 2026-09-20) muss weiter lesbar sein.

## Dependencies
- Upstream: FoundationModels (`GenerationError`-Fälle: rateLimited, guardrailViolation, assetsUnavailable, exceededContextWindowSize, decodingFailure, unsupportedGuide, unsupportedLanguageOrLocale, refusal, concurrentRequests; `LanguageModelError`: contextSizeExceeded, rateLimited, guardrailViolation, refusal, unsupportedCapability, unsupportedTranscriptContent, unsupportedGenerationGuide, unsupportedLanguageOrLocale, timeout — aus dem iOS-27-SDK-Interface gelesen), UIKit (`isIdleTimerDisabled`, `applicationState`), SwiftUI `scenePhase`.
- Downstream: `DateTitleReportTests` liest die Datei; `scripts/measurement-summary.py` liest `results` und `error`.

## Existing Specs
- keine zu Measurement; `docs/project/06-annahmen-und-experimente.md` (A3) beschreibt das Experiment.

## Risks & Considerations
- Apple drosselt bei Akku **und** Hintergrund (DTS, forums/thread/789788: ~4 Anfragen/30 s, Sperre Minuten). Vordergrund + Strom ist die einzige belegte Bedingung ohne Drosselung; auch am Strom gibt es einen bekannten Fehler (FB 153216632).
- Autosperre des iPhones (30 s) schickt die App in den Hintergrund — genau das hat den Lauf am 2026-09-20 beendet. Bildschirm wachhalten ist deshalb Kern, nicht Komfort.
- `Task.sleep` für die Wartezeit muss abbrechbar bleiben (Anhalten während der Wartezeit).
- Ohne Hintergrundlauf ist ein Fernstart per devicectl nur nutzbar, solange das Gerät entsperrt bleibt; für den Nachweis reicht das (Anhalten bei Sperre ist dann selbst ein Ereignis in der Datei).
- Scope: 6 Dateien, ~250 LoC; über der 4–5-Dateien-Grenze wegen project.yml und sim.sh (je wenige Zeilen).

## Analysis

### Type
Bugfix mit Umbau (Feature-Anteil: Lebenslauf und typisierte Fehlerart in der Datei).

Beleg: Gerätelauf 2026-09-20 07:21–07:23, `Measurement/results/date-title.json`. Die App ging
30 s nach dem Start in den Hintergrund (Autosperre), ein Aufruf gelang dort noch, dann drei
Fehlschläge innerhalb 0,5 s (Sicherheitsfilter-Fehler, dann 2× rateLimited) und Stillstand.
Apple DTS (forums/thread/789788): Drosselung bei Akku und Hintergrund, ~4 Anfragen/30 s. Unser
Takt (ein Satz alle ~9 s, sofortiges Nachschieben nach Fehlschlag) trifft die Grenze zwangsläufig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/MeasurementRun.swift` | MODIFY | `MeasurementEvent`, `events` mit abwärtskompatiblem Decoder, `errorKind`, `MeasurementPacing`, `MeasurementErrorKind.classify` |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Hintergrundlauf entfernen; Bildschirm wach halten; Szenenwechsel → Anhalten; Wartezeit nach Fehlschlag; Ereignisse loggen; Fehler typisieren |
| `LooseEndsLab/LabApp.swift` | MODIFY | `scenePhase` an den Runner; Fußtext ohne Hintergrund-Versprechen; Startargument als Ereignis |
| `project.yml` | MODIFY | `UIBackgroundModes` und `BGTaskSchedulerPermittedIdentifiers` am Lab-Target entfernen |
| `scripts/sim.sh` | MODIFY | `lab-run [s]`: Start per devicectl mit `--measure`, Start/Stopp Mac-seitig in `Measurement/results/lab-run.log`, danach `lab-fetch` |
| `LooseEndsTests/MeasurementRunTests.swift` | CREATE | RED: alte Datei lesbar, Roundtrip Ereignisse/Fehlerart, Taktung, Fehlerklassen (bereits angelegt) |

### Scope Assessment
- Files: 6 (davon zwei mit je < 15 Zeilen)
- Estimated LoC: +190 / -70
- Risk Level: LOW — nur Labor-App und Messdatei; die Produkt-App bleibt unberührt. Bestehende
  Ergebnisdatei bleibt lesbar (Test).

### Technical Approach
1. Datei zuerst (reine Typen, testbar auf dem Mac): Ereignisse als Klartext-Strings wie
   `Conditions`; `events` per `decodeIfPresent`; Fehlerart aus `GenerationError` und
   `LanguageModelError` per `switch`, `@unknown default` → „andere".
2. Runner: kein `BackgroundTasks` mehr. `start()` setzt `isIdleTimerDisabled = true`, `stop()`
   zurück. Schleife: messen → Ergebnis mit `errorKind` → sichern → `MeasurementPacing`:
   0 = weiter, 60 s = `Task.sleep` (abbrechbar, Ereignis „wait"), nil = `stop(...)`.
   `scene(_:)` loggt jeden Wechsel und hält bei `.inactive`/`.background` an. Jeder `log` sichert.
3. Oberfläche: `@Environment(\.scenePhase)` + `onChange` → `runner.scene`. Fußtext: „Misst nur,
   solange die App offen ist; der Bildschirm bleibt an. Am besten am Strom."
4. Nachweis: Simulator (`--measure`: 3 Fehlschläge mit Wartezeit-Ereignissen, Anhalten;
   Datei enthält app/model/start/failure/wait/stop). iPhone per `lab-run 40`: Sätze gemessen,
   Autosperre erzeugt Ereignis `scene hintergrund` + `stop`.

### Alternatives considered
- Hintergrund beibehalten mit Takt ≥ 15 s/Anfrage: stützt sich auf eine Forumszahl, verdoppelt
  die Laufzeit, Sperrzeit „Minuten" bleibt unbekannt → verworfen.
- Nur am Strom messen (Sperre im Code): unnötig, Bedingung wird ohnehin je Satz gespeichert und
  im Bericht getrennt → nicht erzwingen, nur empfehlen.

### Dependencies
FoundationModels (Fehlerfälle iOS 27 SDK), UIKit `isIdleTimerDisabled`, SwiftUI `scenePhase`.
Bericht (`DateTitleReportTests`) und `measurement-summary.py` lesen `results` weiter unverändert.

### Open Questions
- keine für den PO. Technische Wahl (Wartezeit 60 s, Abbruch nach 3) ist Tech-Lead-Entscheidung
  und im Bericht sichtbar.
