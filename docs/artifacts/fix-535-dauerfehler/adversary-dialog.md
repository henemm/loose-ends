# Adversary Dialog — fix-535-dauerfehler
Spec: docs/specs/enrichment/fix-535-dauerfehler.md
Datum: 2026-10-21 07:59

## Checkliste
- [x] **AC-1:** Wirft das Modell für eine Notiz `guardrailViolation`, setzt `processPending` danach `processedAt`, schreibt keine `Revision` und lässt `rulesAppliedAt` gesetzt.
- [x] **AC-2:** Wirft das Modell `contextSizeExceeded`, gilt dasselbe wie in AC-1.
- [x] **AC-3:** Nach einem Dauerfehler ruft ein zweites `processPending` das Modell für diese Notiz nicht mehr auf (Aufrufzähler des `StubEnricher` bleibt 1).
- [x] **AC-4:** Bei `timeout`, `ModelDeadline.Exceeded`, `rateLimited`, `assetsUnavailable` und einem unbekannten Fehlertyp bleibt `processedAt` leer; ein zweites `processPending` ruft das Modell erneut auf (Zähler 2).
- [x] **AC-5:** `refusal`, `unsupportedLanguageOrLocale` und `GeneratedContent.ParsingError` gelten als vorübergehend (`ModelFailure.isPermanent == false`), nur `guardrailViolation` und `contextSizeExceeded` als dauerhaft.
- [x] **AC-6:** „Neu analysieren" (`reanalyze`) ruft das Modell für eine dauerhaft abgelehnte Notiz weiterhin auf.
- [x] **AC-7:** `ModelFailure.isPermanent` und `Shared/Enrichment/ModelFailure.swift` kompilieren auf watchOS (ohne FoundationModels liefert die Funktion `false`); der Watch-Build bleibt grün.
- [x] **AC-8:** ADR-4 nennt, dass `processedAt` bei einem dauerhaften Modellfehler ohne KI-Revision gesetzt wird.

## Dialog

### Runde 1
**Adversary:** Runde 1, Beweisforderung je AC. Ich lese Spec, Diff und Tests und fuehre ModelSeamTests selbst aus.
AC-1/2: wo wird processedAt gesetzt, wo bleibt rulesAppliedAt, gibt es eine Revision?
AC-3: Zaehler bleibt 1 beim zweiten Durchlauf?
AC-4: timeout, Deadline, rateLimited, assetsUnavailable, unbekannt bleiben retryable?
AC-5: refusal, unsupportedLanguageOrLocale, ParsingError nicht dauerhaft?
AC-6: ruft reanalyze nach Dauerfehler das Modell?
AC-7: kompiliert ModelFailure ohne FoundationModels (watchOS)?
AC-8: ADR-4 ergaenzt?
**Implementierer:**
AC-1: processedAt wird nur im catch-Zweig und nur bei isPermanent gesetzt; rulesAppliedAt wird vor dem Modellblock gesetzt, context.save() laeuft danach pro Task. Keine Revision, da EnrichmentWriter.apply im Fehlerfall nicht erreicht wird.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:99
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:80
Code reference: LooseEndsTests/ModelSeamTests.swift:111
Testausgabe: "A guardrail refusal is permanent: rules stay, the note is marked, no revision (#535)" bestanden (adversary-test-output.txt, xcresult: 9 Tests passed, 11 passed je Konfiguration, 0 failed, 0 skipped).
AC-2: gleicher Pfad, contextSizeExceeded -> true.
Code reference: Shared/Enrichment/ModelFailure.swift:14
Code reference: LooseEndsTests/ModelSeamTests.swift:122 (Test "An exceeded context window is permanent too (#535)" bestanden).
AC-3: Pending-Fetch verlangt processedAt == nil (zwei Fetches), die Notiz faellt heraus; Test erwartet stub.calls == 1 nach zwei Durchlaeufen, bestanden.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:62
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:68
AC-4: Alles ausser LanguageModelError.guardrailViolation/contextSizeExceeded faellt in default/return false. Tests: timeout, rateLimited, StubFailure je zweimal, calls == 2, processedAt nil (Test "Transient failures stay retryable", Argumente 0,1,2 bestanden). ModelDeadline.Exceeded: Klassifikationstest plus bestehender Hang-Test (slow.processedAt == nil, bestanden). assetsUnavailable ist ein anderer Typ (SystemLanguageModel.Error) als LanguageModelError und kann den as?-Cast nicht treffen.
Code reference: Shared/Enrichment/ModelFailure.swift:12
Code reference: LooseEndsTests/ModelSeamTests.swift:20
AC-5: Klassifikationstest prueft refusal, timeout, rateLimited, unsupportedGenerationGuide, ModelDeadline.Exceeded, StubFailure auf false; guardrail und contextSize auf true.
Code reference: LooseEndsTests/ModelSeamTests.swift:160
AC-6: reanalyze ruft callModel unabhaengig von processedAt; kein Guard darauf. Test: calls steigt um 1, bestanden. Bei Erfolg setzt EnrichmentWriter.apply processedAt normal.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:172
Code reference: Shared/Enrichment/EnrichmentWriter.swift:96
AC-7: Import und Verwendung von LanguageModelError stehen nur unter #if canImport(FoundationModels) && !os(watchOS), sonst return false; gleiches Muster wie FoundationModelsEnricher.swift:1. Die Shared-Quellen sind Teil des Watch-Targets (project.yml:127); der sim-unit-Bau lief durch ("Validate Embedded Binary LooseEndsWatch.app" im Log), also ist der eingebettete Watch-Bau gruen.
Code reference: Shared/Enrichment/ModelFailure.swift:2
Code reference: Shared/Enrichment/FoundationModelsEnricher.swift:1
AC-8: ADR-4 enthaelt den Absatz "Seit #535 setzt ein dauerhafter Modellfehler ... processedAt ohne KI-Revision".
Code reference: docs/project/00-entscheidungen.md:98
Dokumentation am Feld: Shared/Models/TaskItem.swift:21 (nur Kommentar, kein Schema).
Code reference: Shared/Models/TaskItem.swift:21

### Runde 2
**Adversary:** Runde 2, Edge Cases.
(a) Wer liest processedAt und bricht, weil die Notiz nun "vom Modell verarbeitet" gilt? (b) Wird der Fehler vor dem Cast umgewickelt (ModelDeadline, Enricher)? (c) Parallelitaet: reanalyze nach Dauerfehler, isRunning. (d) Speicherfehler nach dem Setzen. (e) Testluecken assetsUnavailable, unsupportedLanguageOrLocale, ParsingError.
**Implementierer:**
(a) grep ueber Shared/, LooseEnds/, LooseEndsWatch, Widgets, Measurement: processedAt wird nur gelesen in den zwei Pending-Fetches (gewollt), in recognitionInputs (liest processedAt != nil ODER rulesAppliedAt != nil, die Notiz steht dort wegen rulesAppliedAt schon, kein Effekt, dedupliziert ueber uniquingKeysWith) und geschrieben im Writer. Keine View und kein Nachzuegler-Pfad liest es. Der "Looks right"-Pfad (#318, processedAt == nil && active) nimmt die Notiz absichtlich nicht mehr auf; das ist das Ziel.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:403
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:68
(b) ModelDeadline.run rethrowt den Fehler der Operation unveraendert, nur Zeitablauf wird zu Exceeded; FoundationModelsEnricher faengt nichts ab (grep catch leer). Der Cast sieht also den echten LanguageModelError.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:37
(c) isRunning-Guard in processPending und reanalyze serialisiert beide; reanalyze hat eigenen callModel-Aufruf ohne processedAt-Pruefung. Ein Teilzustand ist nicht moeglich, da processedAt im selben MainActor-Block vor save gesetzt wird.
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:43
(d) Schlaegt save fehl, bleibt der Wert im Kontext und wird beim naechsten erfolgreichen save geschrieben; im Worst Case einmal Wiederholung beim naechsten Start, kein Datenverlust. Gleiches Verhalten wie beim Erfolgspfad (Writer setzt processedAt auch vor save).
Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:111
(e) Testluecken: assetsUnavailable, unsupportedLanguageOrLocale und GeneratedContent.ParsingError haben keinen eigenen Test; der Klassifikationstest nimmt unsupportedGenerationGuide als Vertreter der unsupported-Familie. Urteil: kein Defekt, weil die Implementierung keine Fallliste fuer "vorübergehend" fuehrt, sondern eine Positivliste fuer "dauerhaft" (zwei Faelle, alle anderen default -> false). Ein weiterer nicht getesteter Fall kann das Ergebnis nicht aendern, ausser jemand erweitert die Liste. assetsUnavailable/ParsingError sind andere Typen und treffen den Cast nicht. Als LOW notiert, weil die Spec-Wortlaute der ACs mehr Namen nennen als die Tests belegen.
Code reference: Shared/Enrichment/ModelFailure.swift:11
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/ModelSeamTests.swift:160
  Description: Klassifikationstest deckt unsupportedLanguageOrLocale, assetsUnavailable und ParsingError nicht einzeln ab (unsupportedGenerationGuide als Vertreter).
  Spec requirement: AC-4/AC-5 nennen diese Faelle
  Conflict: Beleg fuer die genannten Faelle nur indirekt (Positivliste, default false), nicht per Test.
  Remediation: Optional je einen #expect(!isPermanent) fuer unsupportedLanguageOrLocale und ParsingError ergaenzen.
Confirmation:
  AC: AC-1 bis AC-8
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:99
  Evidence: siehe Runde 1; Tests selbst ausgefuehrt, alle bestanden.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Verdacht-Zeile processedAt: einzige Produktions-Schreibstellen EnrichmentWriter.swift:96 (nach erfolgreichem Modelllauf) und EnrichmentCoordinator.swift:101 (nur bei isPermanent im catch). Bedingung davor: Modell lief durch ODER LanguageModelError guardrailViolation/contextSizeExceeded. Test fuer diesen Weg: ModelSeamTests guardrailRefusal und contextWindow (Zweig), emptyAnswer-Test fuer den Writer-Weg.

## Verdict

VERDICT: VERIFIED

Tests: ModelSeamTests 9 bestanden (xcresult), 0 fehlgeschlagen, 0 uebersprungen; Beleg docs/artifacts/fix-535-dauerfehler/adversary-test-output.txt (exit=0).
Alle 8 ACs belegt; einzige Auffaelligkeit F001 (LOW, Testluecke ohne Verhaltensrisiko).

## Geprüfte Dateien

- sha256:53d02f57003c1ab915e7f536674418e40731e9d141fa2f4a86c64b0cbb041345  LooseEndsTests/ModelSeamTests.swift
- sha256:54228633a392a0aa10ca7d8e07958180de61fab2700c1c6996c49b5032952aef  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:68dd1a2ffa61f913b79caa70cbb1676e869612187b2d0059d6c661ce3c0ba0dd  Shared/Enrichment/EnrichmentWriter.swift
- sha256:4f0a5c8840edbbf9154398c06c8f39e21f47c9b84caa7600f45e9781747e8f07  Shared/Enrichment/FoundationModelsEnricher.swift
- sha256:7bc6ff89d1719b0f92095fdba6dbcbdd3f1f3a692e72c2f5be100a5a8bc56026  Shared/Enrichment/ModelFailure.swift
- sha256:66d03745761686ff9dc5072b87aca350a9c9187fb7fc57c44ab6cc90b3009336  Shared/Models/TaskItem.swift
- sha256:4a9f69361b05e0b88fb156d5303ddb7dc05e22b8e806bcabdc0cd95a1ab2dc39  docs/project/00-entscheidungen.md

## Prüfbasis

- base: 6ce15a05448b2ed277eb80a4a876621eda8d402c
- blob:7996e538d5b4b82d403a8d9dabc0e4b14714ae38  LooseEndsTests/ModelSeamTests.swift
- blob:6b730683b51ac79ac50532f6ebecbba75b7d14d2  Shared/Enrichment/EnrichmentCoordinator.swift
- blob:8571edb8b60643b10168415b2ab70700547b5e02  Shared/Enrichment/EnrichmentWriter.swift
- blob:562c1efc704c31be61a6d8b68524b6ab5f6af0b9  Shared/Enrichment/FoundationModelsEnricher.swift
- blob:a3906f492ceddf7b8da637fec381b070c71b2f61  Shared/Enrichment/ModelFailure.swift
- blob:0694ff6d052d6bcabf5c9f184b5e53ca8d5e14ec  Shared/Models/TaskItem.swift
- blob:8a9b2f756b2de82c4d5eb4f9443d93ead31484e1  docs/project/00-entscheidungen.md
