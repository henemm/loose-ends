# Context: fix-536-languagemodelerror

## Request Summary
`LanguageModelSession.GenerationError` ist seit iOS/macOS 27 veraltet (Ticket #536, Epic #563 „Modellaufruf robust“).
Alle Verwendungen auf die Nachfolger umstellen, `MeasurementErrorKind.classify` und die Tests anpassen, und prüfen,
ob der Enricher neue Fehlerarten werfen kann, die der Coordinator anders behandeln müsste.

## Befund im SDK (Xcode 27.1, `FoundationModels.swiftinterface`, iPhoneSimulator)
`GenerationError` ist nicht 1:1 ersetzt, sondern auf vier Typen verteilt (Deprecation-Meldungen im Interface, Z. 3534 ff.):

| Alter Fall | Neuer Ort |
|---|---|
| `rateLimited` | `LanguageModelError.rateLimited(_)` |
| `guardrailViolation` | `LanguageModelError.guardrailViolation(_)` |
| `exceededContextWindowSize` | `LanguageModelError.contextSizeExceeded(_)` |
| `refusal` | `LanguageModelError.refusal(_)` |
| `unsupportedGuide` | `LanguageModelError.unsupportedGenerationGuide(_)` |
| `unsupportedLanguageOrLocale` | `LanguageModelError.unsupportedLanguageOrLocale(_)` |
| `assetsUnavailable` | `SystemLanguageModel.Error.assetsUnavailable(_)` (nicht auf watchOS) |
| `concurrentRequests` | `LanguageModelSession.Error.concurrentRequests` (neu daneben: `transcriptMutationWhileResponding`) |
| `decodingFailure` | `GeneratedContent.ParsingError` (Struct, kein Enum) |

Neu ohne Vorbild: `LanguageModelError.timeout`, `.unsupportedCapability`, `.unsupportedTranscriptContent`.
Weitere Typen im Interface, nicht aus `GenerationError` hervorgegangen: `PrivateCloudComputeLanguageModel.Error`
(networkFailure, quotaLimitReached, serviceUnavailable) — App nutzt kein Private Cloud Compute.
Forum: LanguageModelError lässt sich in einem Antwort-Datenstrom nicht per Muster erkennen (developer.apple.com/forums/thread/831404) — betrifft `streamResponse`, die App nutzt `respond`.

## Related Files
| File | Relevanz |
|------|----------|
| `Measurement/MeasurementRun.swift:212–236` | `MeasurementErrorKind.classify`: Zweig für `GenerationError` (veraltet) UND schon ein Zweig für `LanguageModelError` (Z. 226). Es fehlen `SystemLanguageModel.Error`, `LanguageModelSession.Error`, `GeneratedContent.ParsingError` (heute → „andere“). Konstanten `assetsUnavailable`, `decoding`, `concurrent` existieren schon. |
| `LooseEndsTests/MeasurementRunTests.swift:71–73` | Test `errorKinds` baut `GenerationError`-Werte |
| `LooseEndsTests/ModelSeamTests.swift:104` | `guardrailRefusal` baut `GenerationError.guardrailViolation` für `StubEnricher(failure:)` |
| `LooseEndsLab/MeasurementRunner.swift:152` | einziger Aufrufer von `classify` (Labor-App) |
| `Shared/Enrichment/EnrichmentCoordinator.swift:93–95` | fängt jeden Modellfehler gleich: loggt, Notiz bleibt ohne `processedAt`, Regeln bleiben |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | wirft Fehler des Frameworks unverändert durch (kein eigenes Mapping, keine `GenerationError`-Nennung) |

`grep GenerationError` über alle `*.swift`: genau diese vier Stellen, sonst nirgends.

## Existing Patterns
- Typisierte Fehlerklassen als stabile Strings (`MeasurementErrorKind`), nie Textvergleich.
- `#if canImport(FoundationModels) && !os(watchOS)` um alles Framework-Spezifische.
- Konstruktion in Tests: `Context(debugDescription:)` heute; neue Structs haben `init(debugDescription:metadata:)`.

## Dependencies / Dependents
- Upstream: FoundationModels-SDK (Deployment Target 27, kein `#available` nötig).
- Downstream: `MeasurementRunner` (Lab), Messberichte (`errorKind` in JSON — Strings bleiben stabil, alte Läufe lesbar).
- Coordinator-Verhalten hängt nicht vom Fehlertyp ab → kein Produktpfad betroffen. Unterscheidung dauerhaft/vorübergehend ist #535.

## Risks & Considerations
- Kein Pfad der Geräteliste berührt (Messcode + Tests); `FoundationModelsEnricher`/Coordinator bleiben unverändert.
- Konstruktoren der neuen Fehlerwerte in Tests (`ParsingError`, `SystemLanguageModel.Error.AssetsUnavailable`) evtl. nicht öffentlich → in der Analyse prüfen; sonst nur die konstruierbaren Fälle testen.
- Der alte `GenerationError`-Zweig bleibt nur, wenn Apple ihn noch wirft; Alternative: ersatzlos streichen (Warnung weg). Entscheidung in der Analyse.
- Alternative zum Ticket (Henning: „in Alternativen denken“): `classify` ganz streichen und Fehler nur mit `String(describing:)` loggen — verliert die typisierte Auswertung der Messberichte, daher nicht empfohlen.
- Xcode lokal 27.1; CI pinnt `Xcode_27.app` (27.0): Interface-Unterschiede möglich → Bau in der CI ist der Beleg.

## Analysis

### Type
Bugfix (Veraltet-Warnung im CI-Bau) mit kleiner Erweiterung der Fehlerklassifikation. Kein Produktpfad.

### Befund
- Reproduziert: `GenerationError` kommt nur an vier Stellen vor (`grep` über alle `*.swift`): `MeasurementRun.swift:213`, `MeasurementRunTests.swift:71–73`, `ModelSeamTests.swift:104`. Das ist genau die Liste der CI-Warnung.
- Alle neuen Fehlerwerte sind im SDK (Xcode 27.1, arm64-Simulator-Interface) öffentlich konstruierbar, also testbar:
  `LanguageModelError.<Fall>(.init(debugDescription:))` (Refusal: `explanation:` zusätzlich; ContextSizeExceeded: `contextSize:tokenCount:`; RateLimited: `resetDate:`; UnsupportedGenerationGuide: `schemaName:`; UnsupportedLanguageOrLocale: `languageCode:`; UnsupportedCapability/-TranscriptContent: eigene Pflichtargumente),
  `SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription:))`, `LanguageModelSession.Error.concurrentRequests` / `.transcriptMutationWhileResponding` (ohne Nutzlast), `GeneratedContent.ParsingError(rawContent:debugDescription:)`.
- `classify` hat den `LanguageModelError`-Zweig schon (inkl. `timeout`). Es fehlen: `SystemLanguageModel.Error` → `assetsUnavailable`, `LanguageModelSession.Error` → `concurrent`, `GeneratedContent.ParsingError` → `decoding`. Heute fielen alle drei in „andere“ — die Konstanten dafür existieren, werden aber nie vergeben.
- Zu DoD 3: `FoundationModelsEnricher` fängt und mappt nichts, er reicht Frameworkfehler durch; der Coordinator (`EnrichmentCoordinator.swift:93`) behandelt jeden Fehler gleich (loggen, `processedAt` bleibt leer, Regeln bleiben). Die neuen Arten (`timeout`, `unsupportedCapability`, `unsupportedTranscriptContent`, `transcriptMutationWhileResponding`) ändern daran nichts: Der Coordinator hat ein eigenes 30-s-Limit (`ModelDeadline`), die App nutzt weder Transkript-Mutation noch Private Cloud Compute. Unterscheidung dauerhaft/vorübergehend ist #535, nicht hier.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/MeasurementRun.swift` | MODIFY | `GenerationError`-Zweig streichen; drei neue Zweige (`SystemLanguageModel.Error`, `LanguageModelSession.Error`, `GeneratedContent.ParsingError`) |
| `LooseEndsTests/MeasurementRunTests.swift` | MODIFY | `errorKinds` auf neue Typen, alle Klassen einzeln geprüft |
| `LooseEndsTests/ModelSeamTests.swift` | MODIFY | `guardrailRefusal` baut `LanguageModelError.guardrailViolation(.init(debugDescription:))` |

### Scope Assessment
- Files: 3
- Estimated LoC: +45/−20
- Risk Level: LOW (Messcode und Tests; `FoundationModelsEnricher`/Coordinator unverändert; kein Pfad der Geräteliste berührt)

### Technical Approach
Der alte `GenerationError`-Zweig wird ersatzlos gestrichen (Deployment Target 27; Apple verweist in jeder Deprecation-Meldung auf die Nachfolger, ein behaltener Zweig hielte die Warnung am Leben). Die Rückgabestrings bleiben unverändert, alte Messberichte bleiben lesbar. Tests zuerst (RED): neue Fälle für `assetsUnavailable`, `concurrent`, `decoding` schlagen heute fehl (→ „andere“), Rest sind Umbauten.
Regel-vor-Modell: nicht berührt (reine Typprüfung, kein Modellvorschlag).

### Alternative
`classify` ganz streichen, Fehler nur per `String(describing:)` loggen: weniger Code, aber die typisierte Auswertung der Messberichte (`errorKind`) ginge verloren — verworfen. Eine Entscheidung (ADR) wird dadurch nicht gekippt; ADR-Nr.: keine.

### Dependencies
Upstream FoundationModels-SDK; Downstream nur `LooseEndsLab/MeasurementRunner.swift:152`. CI pinnt Xcode 27.0, lokal 27.1: Der CI-Bau ist der Beleg gegen Interface-Unterschiede.

### Open Questions
- [ ] Keine. (Konstruierbarkeit geprüft, Zweig-Entscheidung getroffen.)
