# Adversary Dialog — fix-536-languagemodelerror
Spec: docs/specs/fix-536-languagemodelerror.md
Datum: 2026-10-20 08:15

## Checkliste
- [x] **AC-1:** Kein `GenerationError` mehr in `*.swift`; der Bau meldet keine Veraltet-Warnung mehr aus diesen Dateien.
- [x] **AC-2:** `MeasurementErrorKind.classify` liefert für jede Fehlerart den bisherigen, unveränderten String (alte Messberichte bleiben lesbar): `LanguageModelError.rateLimited` → „rateLimited“, `.guardrailViolation` → „guardrail“, `.contextSizeExceeded` → „contextWindow“, `.refusal` → „refusal“, `.timeout` → „timeout“, `.unsupportedCapability/-TranscriptContent/-GenerationGuide/-LanguageOrLocale` → „unsupported“.
- [x] **AC-3:** Neu erkannt: `SystemLanguageModel.Error.assetsUnavailable` → „assetsUnavailable“; `LanguageModelSession.Error.concurrentRequests` → „concurrent“; `GeneratedContent.ParsingError` → „decoding“. `LanguageModelSession.Error.transcriptMutationWhileResponding` und jeder fremde Fehler (`NSError`) → „andere“.
- [x] **AC-4:** `MeasurementRunTests.errorKinds` prüft jede Klasse aus AC-2 und AC-3 einzeln mit den neuen Typen; `ModelSeamTests.guardrailRefusal` baut `LanguageModelError.guardrailViolation(.init(debugDescription:))` und bleibt grün (Regeln bleiben, Notiz wartet).
- [x] **AC-5:** Zu DoD 3 geprüft und festgehalten: `FoundationModelsEnricher` und `EnrichmentCoordinator` bleiben unverändert, weil der Coordinator nicht nach Fehlerart unterscheidet und die neuen Arten (`timeout`, `unsupportedCapability`, `unsupportedTranscriptContent`, `transcriptMutationWhileResponding`) daran nichts ändern; Unterscheidung dauerhaft/vorübergehend ist #535.

## Dialog

### Runde 1
**Adversary:** AC-1: Gibt es noch `GenerationError` in `*.swift`? Kommt die Veraltet-Warnung noch vor?
**Implementierer:** `grep -rn GenerationError . --include='*.swift'` liefert keine Treffer. RED-Ausgabe (test-red-output.txt) enthält 2x `MeasurementRun.swift:212:60 'GenerationError' was deprecated in iOS 27.0`; GREEN (test-green-output.txt, 6 Veraltet-Zeilen) enthält 0 aus MeasurementRun.swift, dafür 3x ShareViewController, 2x TaskDetailView, 1x BackgroundRefresh (fremde Dateien, im RED identisch vorhanden). test-green-modelseam.txt: 0. Code reference: Measurement/MeasurementRun.swift:211.
**Adversary:** AC-2: Stimmen die Strings mit dem Vorzustand? Capability/TranscriptContent/LanguageOrLocale sind im Test nicht einzeln belegt.
**Implementierer:** Der Diff zeigt: der `LanguageModelError`-Block ist unverändert (nur Kontextzeilen), die Strings stammen aus denselben Konstanten wie vorher; der alte GenerationError-Zweig (gleiche Konstanten) wurde entfernt. Die vier unsupported-Fälle stehen in einer gemeinsamen case-Liste (Measurement/MeasurementRun.swift:221-223); der Test deckt unsupportedGenerationGuide. Bewertung: ein gemeinsamer Fall, ein Rückgabewert, der Compiler erzwingt Exhaustivität; fehlende Einzelbelege für drei Cases sind LOW (F001), kein Bruch von AC-2.
**Adversary:** AC-3/AC-4/AC-5?
**Implementierer:** Neue Zweige Measurement/MeasurementRun.swift:225-238; Tests LooseEndsTests/MeasurementRunTests.swift:73-82 prüfen zehn Zeilen einzeln inkl. NSError → andere und transcriptMutationWhileResponding → andere. ModelSeamTests.swift:104 baut `LanguageModelError.guardrailViolation(.init(debugDescription:))`, Test „A guardrail refusal …“ grün. Diff gegen origin/main: nur Measurement/MeasurementRun.swift (+ Tests, Doku/Artefakte; LooseEnds/Info.plist ist generiert, ungestagt, außerhalb des Schnitts); keine Änderung in Shared/Enrichment.

### Runde 2
**Adversary:** Edge Cases: Reihenfolge der Typprüfung (kann ein Fehler mehrere Typen erfüllen)? @unknown default? assetsUnavailable/decoding/concurrent kamen vorher nur über GenerationError.
**Implementierer:** Die vier Typen sind disjunkt, Reihenfolge unkritisch. Jeder Switch hat `@unknown default` → andere; `return other` greift außerhalb von canImport(FoundationModels) und für fremde Fehler (NSError-Test). Der Test läuft unter derselben `#if`-Bedingung wie der Code. watchOS bleibt beim reinen „andere“, unverändert zum Vorzustand.
**Adversary:** Grün-Beleg? „Executed 0 tests“ und „1 von 4 übersprungen“?
**Implementierer:** „Executed 0 tests“ betrifft nur XCTest; Swift Testing zählt separat: Suite „Messlauf-Datei und Taktung“ passed, „Fehlerart wird typisiert erkannt, nicht per Textvergleich“ mit Haken, Test Succeeded (test-green-output.txt); Suite „Model seam“ passed (test-green-modelseam.txt). Die Übersprungmeldung gilt SelfConsistencyReportTests (fehlende Messdatei), nicht den geprüften Klassen. AC-5: kein Diff in Shared/Enrichment.
**Adversary:** Restlücke: Die echten SDK-Typen lassen sich nur im Simulator bauen; Beleg ist die Testausgabe, nicht neu ausgeführt (Testsperre). Akzeptiert: RED (Warnung + Fehlschlag) und GREEN sind konsistent.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/MeasurementRun.swift:221
  Description: unsupportedCapability, unsupportedTranscriptContent, unsupportedLanguageOrLocale teilen sich mit unsupportedGenerationGuide eine case-Liste; der Test belegt nur unsupportedGenerationGuide.
  Spec requirement: AC-2 — alle vier → „unsupported“
  Conflict: Keine Verletzung; nur fehlender Einzelbeleg, die Konstruktoren dieser Cases sind im Test nicht aufgerufen.
  Remediation: Optional drei weitere #expect-Zeilen.

Confirmation:
  AC: AC-1
  Code reference: Measurement/MeasurementRun.swift:211
  Evidence: kein GenerationError in *.swift, Warnung aus RED (2x) in GREEN verschwunden.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Measurement/MeasurementRun.swift:212
  Evidence: LanguageModelError-Block unverändert, Strings identisch, Tests Zeilen 73-78 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/MeasurementRun.swift:225
  Evidence: Zweige für SystemLanguageModel.Error, LanguageModelSession.Error, ParsingError; Tests Zeilen 79-82 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Measurement/MeasurementRun.swift:238
  Evidence: errorKinds prüft alle Klassen einzeln (außer drei gemeinsam geführte unsupported-Cases, F001); ModelSeamTests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Measurement/MeasurementRun.swift:241
  Evidence: kein Diff in Shared/Enrichment; classify wirkt nur auf den Messbericht.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: MeasurementRunTests und ModelSeamTests grün (Swift Testing, Test Succeeded), 0 failed; Messstrecke SelfConsistencyReportTests übersprungen (fehlende Messdatei, nicht Teil dieses Schnitts)
Edge cases: geprüft, nur F001 (LOW)
Regressions: keine
Checklist: 5/5 proven

## Geprüfte Dateien

- sha256:86e701b1834722c04a3da518993aeaf56de42bf4cdbbe4d9d92f3f25699e2078  Measurement/MeasurementRun.swift

## Prüfbasis

- base: 470b7111de6050875ba0b0fc5c57f605c315519b
- blob:f16ab115a5c967f32d075dd5ad7887e231ab0aff  Measurement/MeasurementRun.swift
