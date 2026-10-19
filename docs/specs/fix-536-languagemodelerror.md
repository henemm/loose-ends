# Spec: Fehlerklassifikation ohne veraltetes `GenerationError` (#536)

Epic #563 „Modellaufruf robust“. Der CI-Bau warnt, weil `LanguageModelSession.GenerationError` seit iOS/macOS 27 veraltet ist.

**ADR-Nr.:** keine — reine Typprüfung im Messcode, keine Entscheidung gekippt.

## Problem

`GenerationError` kommt an genau drei Dateien vor: `Measurement/MeasurementRun.swift` (`MeasurementErrorKind.classify`),
`LooseEndsTests/MeasurementRunTests.swift`, `LooseEndsTests/ModelSeamTests.swift`. Apple hat seine Fälle auf vier Typen verteilt
(`LanguageModelError`, `SystemLanguageModel.Error`, `LanguageModelSession.Error`, `GeneratedContent.ParsingError`). `classify` kennt
`LanguageModelError` schon, erkennt aber die drei anderen nicht: `assetsUnavailable`, `concurrent`, `decoding` fielen heute in „andere“,
obwohl die Konstanten existieren. Der Produktpfad ist nicht betroffen: `FoundationModelsEnricher` reicht Frameworkfehler unverändert
durch, `EnrichmentCoordinator` behandelt jeden Fehler gleich (loggen, `processedAt` bleibt leer, Regeln bleiben).

## Expected Behavior

- **AC-1:** Kein `GenerationError` mehr in `*.swift`; der Bau meldet keine Veraltet-Warnung mehr aus diesen Dateien.
- **AC-2:** `MeasurementErrorKind.classify` liefert für jede Fehlerart den bisherigen, unveränderten String (alte Messberichte bleiben lesbar):
  `LanguageModelError.rateLimited` → „rateLimited“, `.guardrailViolation` → „guardrail“, `.contextSizeExceeded` → „contextWindow“,
  `.refusal` → „refusal“, `.timeout` → „timeout“, `.unsupportedCapability/-TranscriptContent/-GenerationGuide/-LanguageOrLocale` → „unsupported“.
- **AC-3:** Neu erkannt: `SystemLanguageModel.Error.assetsUnavailable` → „assetsUnavailable“; `LanguageModelSession.Error.concurrentRequests`
  → „concurrent“; `GeneratedContent.ParsingError` → „decoding“. `LanguageModelSession.Error.transcriptMutationWhileResponding` und jeder
  fremde Fehler (`NSError`) → „andere“.
- **AC-4:** `MeasurementRunTests.errorKinds` prüft jede Klasse aus AC-2 und AC-3 einzeln mit den neuen Typen; `ModelSeamTests.guardrailRefusal`
  baut `LanguageModelError.guardrailViolation(.init(debugDescription:))` und bleibt grün (Regeln bleiben, Notiz wartet).
- **AC-5:** Zu DoD 3 geprüft und festgehalten: `FoundationModelsEnricher` und `EnrichmentCoordinator` bleiben unverändert, weil der Coordinator
  nicht nach Fehlerart unterscheidet und die neuen Arten (`timeout`, `unsupportedCapability`, `unsupportedTranscriptContent`,
  `transcriptMutationWhileResponding`) daran nichts ändern; Unterscheidung dauerhaft/vorübergehend ist #535.

## Scope

Dateien (3): `Measurement/MeasurementRun.swift`, `LooseEndsTests/MeasurementRunTests.swift`, `LooseEndsTests/ModelSeamTests.swift`.
Geschätzt +45/−20 LoC. Keine neuen Permissions, keine AppStorage-Keys, keine Modelländerung (kein CloudKit-Schema).
Kein Pfad der Geräteliste berührt.

## Tests (TDD)

Unit-Tests zuerst (RED): die Fälle `assetsUnavailable`, `concurrent`, `decoding` schlagen heute fehl (→ „andere“). Die übrigen sind Umbauten.
Konstruktion: `LanguageModelError.<Fall>(.init(debugDescription:))` (Sonderargumente je Fall laut SDK-Interface), `SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription:))`,
`LanguageModelSession.Error.concurrentRequests`, `GeneratedContent.ParsingError(rawContent:debugDescription:)`.
Simulator-Durchlauf: Kein sichtbarer Ablauf geändert; Beleg ist der grüne Unit-Lauf im Simulator und der Bau ohne Warnung (`sim.sh build`).

## Alternativen (verworfen)

- `GenerationError`-Zweig behalten: hielte die Warnung am Leben; Deployment Target ist 27.
- `classify` streichen, nur `String(describing:)` loggen: weniger Code, aber die typisierte Auswertung (`errorKind` in Messberichten) ginge verloren.
