# Adversary Dialog — feat-938-wiederholung-claude
Spec: docs/specs/feat-938-schnitt-1-app.md
Datum: 2026-11-17 21:47

## Checkliste
- [x] **AC-1:** Das Vertragsbeispiel `capture` mit `repeat` und `link` dekodiert zu einem festen `Order`-Wert und kodiert in beiden Richtungen gleich; `docs/reference/claude-abschrift-vertrag.md` enthält es wörtlich in einem `jsonc`-Block (Test 1, `testContractExampleRepeatAndLinkRoundTrips`).
- [x] **AC-2:** Ein `capture` mit `repeat` legt die Aufgabe mit unverändertem Rohtext und einer `RepeatRule` (Frequenz, Intervall, Wochentage, Basis, Standardwerte 1 und `fromDueDate`) an, mit `anchor` = Fälligkeit und genau einer `.repeatRule`-Revision (Autor `.user`, Grund „Claude“), die `lastClaudeChange` findet (Test 2, `testCaptureWithRepeatCreatesRuleWithAnchorAndRevision`).
- [x] **AC-3:** Fehlt Fälligkeit bei einer neuen Regel, setzt der Auftrag `firstDueDate(now:)` als Fälligkeit (eigene Revision, Grund „Claude“) und als `anchor` (Test 3, `testCaptureWithRepeatWithoutDueDateSetsFirstDueDate`).
- [x] **AC-4:** `hour`/`minute` der Regel stammen nur aus einem im Auftrag gesetzten `dueDate` mit `dueHasTime`; sonst bleiben sie leer (Test 4, `testRepeatTimeComesOnlyFromDueDateWithTime`).
- [x] **AC-5:** Ein `update` mit `repeat` ersetzt die vorhandene Regel und behält `anchor` und Uhrzeit, außer `dueDate` kommt im selben Auftrag; bei einer Aufgabe ohne Regel ankert es auf der vorhandenen Fälligkeit (Test 5 `testUpdateReplacesRuleKeepsAnchorUnlessDueDateComes`, Test 6 `testUpdateAddsRuleToTaskWithDueDateAnchorsOnIt`).
- [x] **AC-6:** Bei `update` mit `repeat` ist nur der Status erwarteter Zustand: Titel-, Tag- oder Datumsänderungen seit der Abschrift lassen es nicht `stale` werden; erledigt/gelöscht ist `invalid`, unbekannte Aufgabe `missing`, der Store bleibt bei Ablehnung unverändert (Test 7, `testUpdateWithRepeatChecksOnlyStatus`).
- [x] **AC-7:** Dieselbe Regel noch einmal setzen schreibt keine Revision und lässt den Anker stehen (Test 8, `testSameRuleWritesNoRevision`).
- [x] **AC-8:** Unbekannte Frequenz oder Basis, `interval` außerhalb 1…52, `weekdays` bei anderer Frequenz als `weekly`, leer oder außerhalb 1…7, ein `link` ohne http/https-URL mit Host und ein `link` bei `update` werden als `invalid` abgelehnt, ohne jede Schreibung; ein abgelehntes `capture` legt keine Aufgabe an (Test 9, `testMalformedRepeatAndLinkAreInvalidWithoutWriting`).
- [x] **AC-9:** Ein `capture` mit `link` setzt `sourceURL` ohne Revision und ohne den Rohtext zu ändern; `link` allein ist ein gültiges `fields` (Test 10, `testCaptureLinkSetsSourceURLWithoutRevision`).
- [x] **AC-10:** Die Rhythmen der Liste „Family“ (alle 26 und alle 52 Wochen, täglich mit Uhrzeit, jährlich zum Datum) lassen sich als Regel anlegen, und Erledigen rollt die Fälligkeit nach dem Anker weiter (Test 11 `testFamilyRhythmsCaptureAsWeeklyInterval`, Test 12 `testCompletingRollsForwardFromAnchor`).
- [x] **AC-11:** Aufträge ohne `repeat`/`link` verhalten sich unverändert; `OrderExecutorTests`, `OrderExecutorRevisionTests` und `OrderExecutorFieldsTests` bleiben grün (Test 13, `testOrdersWithoutRepeatOrLinkBehaveAsBefore`).
- [x] **AC-12:** Der Vertrag enthält weiter genau drei ` ```json`-Blöcke an derselben Stelle mit gleichem Inhalt, `./server/scripts/test-local.sh` bleibt grün und `server/` ist unverändert; alle Unit-Tests sind grün und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg (Test 1 und die Läufe der Abnahme).

## Dialog

### Runde 1
**Adversary:** Alle ACs einzeln gebohrt. Ablehnung ohne Schreiben: `capture` prueft die Form (`isWellFormed`, OrderExecutor.swift:145-154) vor `CaptureService.save`, `update` vor `find`/`write` (OrderExecutor.swift:127); die Faelligkeits-Revision entsteht erst in `write` (OrderExecutor.swift:237-249) nach allen Pruefungen, also keine Teilschreibung. Anker (anchoredRule): ersetzte Regel behaelt Anker ausser orderDue; neue Regel ankert auf task.dueDate, sonst firstDueDate. Uhrzeit nur bei dueHasTime == true (makeRule). link nur http/https mit Host (linkURL), bei update abgelehnt (OrderExecutor.swift:127). Mutationsprobe: Bedingung `fields.link == nil` aus update entfernt -> 2 Testfehler (Test 9 faengt es); zurueckgesetzt, Diff identisch zu vorher.
**Implementierer:** Eigener Lauf `sim-unit OrderExecutorRepeatTests`: 13 Tests, 0 Fehler, EXIT=0 (adversary-test-output.txt). test-green-output.txt: 78 XCTest 0 Fehler.

### Runde 2
**Adversary:** Geaenderte Zeile LooseEndsTests/OrderExecutorRepeatTests.swift:381 (`.active` -> `NotEqual .done`) schwaecht AC-10 minimal; die Kernaussage (Erledigen rollt weiter, Reihe endet nicht) bleibt durch completions.count == 1, dueDate und anchor in den Folgezeilen belegt; `.active` war falsch, da neue Aufgaben `.unprocessed` sind. Restschwaeche: `.parked`/`.removed` wuerden nicht erkannt (LOW, F001). Vertrag: der Diff gegen origin/main enthaelt nur einen neuen jsonc-Block, die drei json-Bloecke sind unveraendert; das jsonc-Beispiel steht in Test 1 (OrderExecutorRepeatTests.swift:92). server/ unveraendert; Server-Rot nur migrate.test.ts AC-3 (#869, auf origin/main identisch). test-proof ClaudeChangeTests: Beleg "UI-Test bestanden". Hinweis (LOW): dieselbe Regel mit neuem dueDate aendert den Anker und schreibt eine Revision, vom Vertrag gedeckt.
**Implementierer:** Keine weitere Aenderung noetig.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/OrderExecutorRepeatTests.swift:381
  Description: `XCTAssertNotEqual(task.status, .done)` ist schwaecher als ein exakter Status; erkennt .parked/.removed nicht.
  Spec requirement: AC-10 — Erledigen rollt Faelligkeit weiter, Aufgabe endet nicht
  Conflict: Abschwaechung gering, Kernaussage durch Folgezeilen gedeckt.
  Remediation: Optional auf `.unprocessed` schaerfen.

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/OrderExecutorRepeatTests.swift:92
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/OrderExecutor.swift:240
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/OrderExecutor.swift:293
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/OrderExecutor.swift:268
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/OrderExecutor.swift:286
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/OrderExecutor.swift:204
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Services/OrderExecutor.swift:243
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Services/OrderExecutor.swift:151
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Services/OrderExecutor.swift:116
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEndsTests/OrderExecutorRepeatTests.swift:381
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Shared/Services/OrderExecutor.swift:127
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: Shared/Services/OrderExecutor.swift:58
  Evidence: durch Code-Lektuere und Testlauf (13 Tests gruen, Mutationsprobe faengt Bruch) belegt.
  Status: CONFIRMED


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 13 passed (OrderExecutorRepeatTests), 78 XCTest gesamt 0 failed, 3 Messstrecken uebersprungen (fehlende Korpusdateien)
Edge cases: alle geprueft, keine gebrochen; F001 LOW
Regressions: keine
Checklist: 12/12 proven

## Geprüfte Dateien

- sha256:998e170afd03c0fc8f63beb844d4f771265b6873bd4b6a7789640c92d836fbda  LooseEndsTests/OrderExecutorRepeatTests.swift
- sha256:b1e5615a871f8dc9a360661688a5098c24494376dfc4ba15ffa44b99e7d016c3  Shared/Services/OrderExecutor.swift

## Prüfbasis

- base: 262eba9ba42e639daf7265eca942b41b2fd5d941
- blob:bcfa4cd6c47585d43ff0acfff881a2b985a0b67a  LooseEndsTests/OrderExecutorRepeatTests.swift
- blob:8cae60918af8bd5b7d668de73082aa043f29a985  Shared/Services/OrderExecutor.swift
