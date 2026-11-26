# Adversary Dialog — feat-982-modell-ausbauen
Spec: docs/specs/enrichment/feat-982-schnitt-1-modell-raus.md
Datum: 2026-11-26 09:33

## Checkliste
- [x] **AC-1:** Nach Erfassung von „Vor Konzert“ und `processPending` hat die Aufgabe den Titel „Vor Konzert“, keine Dauer, keine Revision mit Autor `.ai`, `processedAt == nil` und `rulesAppliedAt != nil` (Test 1).
- [x] **AC-2:** Eine genannte Dauer („Vor Konzert 20 Minuten“) setzt weiter die Regeldauer, und eine wiedererkannte Aufgabe bekommt weiter Dauer und Kontexte aus `RecognitionRule` (Test 2).
- [x] **AC-3:** Eine Aufgabe mit gesetztem `rulesAppliedAt` wird von einem späteren `processPending` nicht angefasst: keine neue Revision, `rulesAppliedAt` unverändert (Test 3).
- [x] **AC-4:** Eine Aufgabe mit `processedAt` gesetzt und `rulesAppliedAt == nil` (Stand von vor #144) bekommt mit „20 Minuten“ im Text von `processPending` keine Dauer-Revision (Test 4).
- [x] **AC-5:** `reanalyze` läuft nur die Regeln und liefert `.finished(changed:)`; alte KI-Werte und KI-Revisionen bleiben unverändert, außer eine Regel findet für ein Feld, das der Nutzer nie gesetzt hat (keine Nutzer-Revision), einen abweichenden Wert; dann kommt eine neue Revision dazu, die alte bleibt (Tests 5 und 6).
- [x] **AC-6:** Die Detailansicht zeigt nach „Neu analysieren“ nie „Apple Intelligence did not run, only the rules.“ (Test 11 tippt „Analyze again“ in der Detailansicht und prüft, dass der Satz nicht erscheint; Test 6 belegt das Ergebnis `.finished(changed:)`).
- [x] **AC-7:** `EnrichmentCoordinator` hat keinen Weg mehr, ein Modell zu empfangen oder aufzurufen: nur `init(container:savedPlaces:)`, kein `enricher`, kein `callModel` (Test 7, Kompilierbeweis).
- [x] **AC-8:** Das Onboarding der echten App (ohne UI-Test-Argument) zeigt keinen Apple-Intelligence-Hinweis; der Grund ist `nil`, außer `--ui-testing-model-reason=` ist gesetzt (Test 8).
- [x] **AC-9:** Im Simulator, ohne `--ui-testing`, zeigt `NoModelCaptureTests` für die getippte Erfassung „Vor Konzert“: Titel „Vor Konzert“, keine Dauer, keine KI-Kennzeichnung (Test 11, Beleg über `./scripts/sim.sh test-proof NoModelCaptureTests`).
- [x] **AC-10:** Teilaufgaben und die Mac-Menüleisten-Erfassung führen den Regelschritt weiter aus (`processPending` wird gerufen, Teilschritte unverändert) (Tests 9 und 10).

## Dialog

### Runde 1
**Adversary:** Angriff auf die Nachzügler-Auswahl: `pendingTasks` verlangt `processedAt == nil && rulesAppliedAt == nil`. (a) Alt-Aufgabe mit processedAt aber ohne rulesAppliedAt (vor #144) wird ausgeschlossen, gewollt (AC-4). (b) „Looks right“ vor dem Regelschritt: zweiter Fetch `active` + rulesAppliedAt == nil + parent == nil, Aufgabe bekommt ihren einen Lauf; danach nie wieder (AC-3). (c) Aus Geparkt reaktivierte Aufgabe mit gesetztem rulesAppliedAt läuft nicht erneut, vorher (Modell) lief sie; Regeln sind jedoch einmalig, daher kein Verlust. (d) Teilaufgaben: `applySubtaskRules(in:)` läuft vor dem Durchlauf, der Hauptdurchlauf filtert `parent == nil`. Reanalyze-Zusammenlegung: `task.parent != nil` -> nur `applySubtaskRules`, sonst `applyRules`; rulesAppliedAt in beiden gesetzt; Verhalten wie vorher (nur der Rückgabetyp ohne modelRan). Kein FoundationModelsEnricher mehr in LooseEnds/ oder Koordinator (grep: nur Doc-Kommentare in OnboardingFlow/OnboardingView, Datei Shared/Enrichment/FoundationModelsEnricher.swift bleibt für Schnitt 3, Labor LooseEndsLab/MeasurementRunner.swift nutzt sie weiter und kompiliert; nichts Gelöschtes referenziert, ModelDeadline/ModelFailure existieren noch). Swift-Concurrency: Koordinator bleibt @MainActor, kein neues try?, Logger statt print.
**Implementierer:** Belege: Unit-Lauf `./scripts/sim.sh unit` grün, UI-Test NoModelCaptureTests grün (adversary-test-output.txt).

### Runde 2
**Adversary:** Gelöschte Tests: ~43 Testköpfe entfernt, 20 neu; entfernt wurden nur Fälle, die Modellaufruf, Timeout, Guardrail-Pipeline, KI-Titel prüfen. Regelabdeckung ist als Umschreibung erhalten (Datum, Nachhol-Doppelrevision, Looks right #318, Erkennung, Energie, Siri, Teilaufgaben, Titel-Behalt). ModelUnavailableTests entfernt (reiner Modell-Zweig). Rest: ModelSeamTests behält die Fehlerklassifikation von ModelFailure (Schnitt 3). ReviewNote: Änderung minimal (hint wird optional, nur der Fall .notSortedYet entfällt) und korrekt, denn der Satz „by itself once Apple Intelligence is ready“ wäre falsch; Screenshot zeigt „Not sorted yet“ ohne Zusatzzeile, im Detail „Nothing new found.“ ohne KI-Satz (AC-6). Onboarding: `onboardingModelReason` liefert ohne UI-Test nil (AC-8, Test 177 ff.). UI-Test läuft ohne `--ui-testing` (Zeile 42) mit echter Verdrahtung (AC-9). Menüleiste ruft weiter processPending (MenuBarCapture.swift:19, AC-10, Test 206). Rest-Beanstandungen niedrig: verwaister Katalogschlüssel (LOW), Dauer-Prüfung im UI-Test per Label-Heuristik (' min'/' h', LOW).
**Implementierer:** Keine weiteren Einwände; beide Rest-Punkte nur kosmetisch.

### Strukturierte Bestätigungen
Confirmation: AC: AC-1, AC-2, AC-3, AC-4
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:90
  Evidence: pendingTasks-Prädikat, rulesAppliedAt nach applyRules gesetzt, Tests 1-4 grün
  Status: CONFIRMED
Confirmation: AC: AC-5, AC-7
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:96
  Evidence: reanalyze nur Regeln, `.finished(changed:)`, init(container:savedPlaces:) ohne Modell
  Status: CONFIRMED
Confirmation: AC: AC-6
  Code reference: LooseEnds/Views/TaskDetailView.swift:659
  Evidence: Fall `.finished(let changed)` ohne KI-Satz; UI-Test grün
  Status: CONFIRMED
Confirmation: AC: AC-7
  Code reference: LooseEnds/App/LooseEndsApp.swift:45
  Evidence: Koordinator ohne Enricher gebaut
  Status: CONFIRMED
Confirmation: AC: AC-8
  Code reference: LooseEnds/App/ContentView.swift:36
  Evidence: onboardingModelReason nil ohne ui-testing-Argument
  Status: CONFIRMED
Confirmation: AC: AC-9
  Code reference: LooseEnds/Views/ReviewNote.swift:13
  Evidence: kein falscher Hinweis, NoModelCaptureTests grün ohne --ui-testing
  Status: CONFIRMED
Confirmation: AC: AC-10
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:47
  Evidence: Teilaufgaben-Regeln vor Hauptdurchlauf, reanalyze-Zweig parent != nil
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/ReviewNote.swift:41
  Description: Katalogschlüssel „That happens by itself once Apple Intelligence is ready.“ bleibt in Localizable.xcstrings:186 ungenutzt.
  Spec requirement: AC-9 — kein falscher Hinweis
  Conflict: nur toter Eintrag, kein Fehlverhalten
  Remediation: in Schnitt 2/3 entfernen

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: Unit-Lauf grün (0 Fehler), UI NoModelCaptureTests 1 bestanden, 0 fehlgeschlagen; Messstrecken 3 von 6 übersprungen (fehlende Korpusdateien, nicht Teil dieses Schnitts)
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:9ce643bfa47ca006c04190d4aa238440a6a2588d14ee25f9c133fed9a9a9e3f4  LooseEnds/App/ContentView.swift
- sha256:3e593035e977eb26d5dbff1af698230ced4bcf06e9e2db278c38144f75a9a75e  LooseEnds/App/LooseEndsApp.swift
- sha256:f055f52692540a1915fa2ea466c9fb8aa2f8e3573fcdae94106231806444c2ff  LooseEnds/Views/ReviewNote.swift
- sha256:c09e1f0992e752d14688e4bacd7345bf14ddf389df093a19079b9b2230c75d52  LooseEnds/Views/TaskDetailView.swift
- sha256:18cda44d62787ccd9ab604a333a95f175127a95610fa4966f86b2eba96657177  Shared/Enrichment/EnrichmentCoordinator.swift

## Prüfbasis

- base: 852a3d30b77a478fc707f93ab9a9631ffbdd2051
- blob:35b8c1c9246b7cc382d0de10b177450d82606d36  LooseEnds/App/ContentView.swift
- blob:c4ee4387d099c73daa2805db452e2e42c558ecf2  LooseEnds/App/LooseEndsApp.swift
- blob:fb4a2d2607dc1ec79456073bfadec025fd70d6f3  LooseEnds/Views/ReviewNote.swift
- blob:775e47168bf938f4e49f1eda60615e2c20d80af2  LooseEnds/Views/TaskDetailView.swift
- blob:77713db5878df234920a0ac345569f71c6e35bee  Shared/Enrichment/EnrichmentCoordinator.swift
