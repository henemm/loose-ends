# Adversary Dialog — fix-953-claude-titel
Spec: docs/specs/bug-953-claude-titel.md
Datum: 2026-11-19 08:21

## Checkliste
- [x] **AC-1:** Eine per `capture` ohne `fields` angelegte Claude-Aufgabe behält nach dem Erstlauf der Anreicherung ihren Regeltitel; das Modell schreibt keine Titel-Revision (Test 1).
- [x] **AC-2:** Bei „Erneut analysieren“ einer Claude-Aufgabe bleibt der Titel unverändert (Test 2).
- [x] **AC-3:** Eine Claude-Aufgabe endet nach der Anreicherung mit Status `active`, nie hängend in `unverified` (Test 3).
- [x] **AC-4:** Die vom Modell gelieferte Dauer (und die Regelfelder) werden bei Claude-Aufgaben weiter gesetzt (Test 4).
- [x] **AC-5:** Gegenprobe: Eine aus der App erfasste Aufgabe (Kanal `.app`) wird weiter vom Modell verfeinert (Test 5).
- [x] **AC-6:** Ein von Claude mit `fields.title` gesetzter Titel bleibt erhalten (Test 6).
- [x] **AC-7:** Der Nachstellungslauf aus `docs/artifacts/fix-953-claude-titel/nachstellung.md` zeigt im Simulator den Fehler nicht mehr (Titel bleibt „Angebot für die Gartenhütte bei Müller einholen“, Erstlauf und Neuanalyse).

## Dialog

### Runde 1
**Adversary:** Testlauf selbst: `./scripts/sim.sh sim-unit ClaudeTitleTests` -> 6 Tests, 0 Failures (adversary-test-output.txt). Uebersprungen im Gesamtlauf nur Messstrecken ohne Bezug (3 von 6, fehlende Korpusdateien). Jedes AC einzeln geprueft:

Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:48
  Evidence: `fromClaude = task.capturedVia == .claude` verschliesst den Modell-Titelzweig; Test 1 (ClaudeTitleTests.swift:44-56) prueft Titel unveraendert und keine .ai-Titelrevision, stub.calls == 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/ClaudeTitleTests.swift:60
  Evidence: reanalyze mit anderem Stub-Titel; Titel bleibt, keine Revision. Reanalyze laeuft ueber denselben EnrichmentWriter.apply (EnrichmentCoordinator.swift:190).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:64
  Evidence: neuer else-if hebt unprocessed/unverified -> active, sobald ein Titel steht; Test 3 (ClaudeTitleTests.swift:77) mit Modelltitel nil.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsTests/ClaudeTitleTests.swift:91
  Evidence: Dauer-Block (Writer Z. 60-67) ist vom Claude-Flag unberuehrt; Test 4 prueft duration .minutes30 mit Quelle ai.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsTests/ClaudeTitleTests.swift:107
  Evidence: Kanal .app wird weiter verfeinert (Titel = Modelltitel, 1 .ai-Revision, active). Der alte Zweig ist fuer !fromClaude identisch (Bedingung nur um `!fromClaude` ergaenzt).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsTests/ClaudeTitleTests.swift:123
  Evidence: fields.title -> titleSourceRaw user; Titel haelt Erstlauf und Neuanalyse.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsTests/ClaudeTitleTests.swift:23
  Evidence: Der Test-Helper `capture` ruft OrderExecutorTests.run (OrderExecutor.execute, capture ohne fields), danach EnrichmentCoordinator.processPending/reanalyze mit StubEnricher, derselbe Satz "Angebot fuer die Gartenhuette bei Mueller einholen" und derselbe Stub-Titel "Angebot Gartenhuette einholen" wie in nachstellung.md; dort schlug exakt dieser Weg fehl, jetzt gruen. Gleicher Codepfad, nur Wegwerf-Suite durch eingecheckte Suite ersetzt. Echtes Modell im Simulator nicht verfuegbar (Nachstellung sagt dasselbe).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt; Kontextisolation)

### Runde 2
**Adversary:** Edge Cases und Regressionen.
- Unteraufgaben (capturedVia .claude via Subtasks.add): EnrichmentCoordinator filtert `$0.parent == nil` (Z. 82) und reanalyze verzweigt bei `task.parent != nil` (Z. 148); der Writer wird fuer Unteraufgaben nicht erreicht. Nicht betroffen.
- Andere Schreiber des Titels: grep nach `.title =` in Shared/LooseEnds: nur Writer (Z. 58, jetzt geschuetzt), FieldCodec (Nutzer-Reset), Subtasks, SiriCapture, CaptureService (Regeltitel). RecognitionRule setzt nur Kontexte/Dauer. Kein weiterer Modellpfad.
- Reanalyze einer bereits aktiven Claude-Aufgabe: kein Statuswechsel noetig, Titel unveraendert (Test 2).
- Modelltitel unter Schwelle: ohne Belang, Zweig ist fuer Claude ohnehin zu.
- Statusregeln App-Aufgaben: else-if-Kette fuer !fromClaude unveraendert.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:66
  Description: Hat eine Claude-Aufgabe keinen Regeltitel (task.title == nil), faellt sie in den Zweig unprocessed -> unverified; das Modell kann ihr, anders als vorher, keinen Titel mehr geben.
  Spec requirement: AC-3 — nie haengend in unverified (gilt nur bei vorhandenem Titel)
  Conflict: Praktisch nicht erreichbar (capture verlangt Text, nicht-leerer Text ergibt einen Titel); kein Test dafuer. Kein Blocker.
  Remediation: Optional ein Test fuer title == nil.

Restrisiko laut Spec (aelterer Bau auf anderem Geraet) ist dokumentiert, nicht per Code pruefbar.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 6 passed, 0 failed, 0 uebersprungen (ClaudeTitleTests)
Edge cases: Unteraufgaben, andere Kanaele, Reanalyze, weitere Titelschreiber geprueft; nur F001 (LOW, praktisch unerreichbar)
Regressions: None found
Checklist: 7/7 points proven

## Geprüfte Dateien

- sha256:120130e5a451ade4c7fccdda43df1724c5df55d838a09cde77cc643cbb54ba06  LooseEndsTests/ClaudeTitleTests.swift
- sha256:d6a3f4547f4c5d338d7b6e8e973638687e70a4ed6523a105a1f1f9e49291872f  Shared/Enrichment/EnrichmentWriter.swift

## Prüfbasis

- base: 57963cd6ce7249f9663c3df59eb74c57803fab21
- blob:89b373a6ebd39873eab329c7f902c21f99aa84be  LooseEndsTests/ClaudeTitleTests.swift
- blob:6d21376bb9a5e3e02993752d50a60b215ca121f6  Shared/Enrichment/EnrichmentWriter.swift
