# Adversary Dialog — fix-972-fields-smoke-flaky
Spec: docs/specs/fix-972-fields-smoke-flaky.md
Datum: 2026-11-21 08:12

## Checkliste
- [x] **AC-1:** `choose(_:in:app:)` tippt die Option über die id `levelOption_<raw>`, wartet mit `waitForNonExistence(timeout: 15)` auf das Schließen des Editors und prüft danach die Zeilenbeschriftung mit 15 s Budget; kein 5-s-`XCTWaiter` mehr in diesem Helfer.
- [x] **AC-2:** `testCalendarWaitsForADate` merkt den Kalendertag vor der Erfassung und erwartet nach dem Lesen „Today“ bei Tageswechsel, sonst „Tomorrow“.
- [x] **AC-3:** `./scripts/sim.sh test-proof FieldsSmokeTests` ist zehnmal hintereinander grün, mit registriertem Simulator-Beleg.
- [x] **AC-4:** Der Diff berührt nur `LooseEndsUITests/FieldsSmokeTests.swift` und keine App-Datei (App-LoC 0).

## Dialog

### Runde 1
**Adversary:** Kann `waitForNonExistence` auf der Option sofort fälschlich erfüllt sein, wenn die id falsch ist? Stimmen id und raw?
**Implementierer:** Nein: davor steht `waitForExistence(timeout: 5)` auf demselben Button `levelOption_<level.lowercased()>`; bei falscher id scheitert diese Zeile. EditorPage.swift setzt die Kennung `levelOption_` plus raw (`low`/`medium`/`high`); Aufrufer übergeben "Medium"/"Low" und damit `medium`/`low`. Passt.
Code reference: LooseEnds/Views/EditorPage.swift:92
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:231

**Adversary:** Deckt `testLineWaitOutlastsOneSlowQuery` das 15-s-Budget?
**Implementierer:** Nur die Klasse "eine 4,2-s-Abfrage frisst nicht das Budget" (Stub `SlowLine`, Lauf ca. 6 s, die 15 s selbst werden nicht ausgereizt). Das reicht für den belegten CI-Fehler. Kein 5-s-XCTWaiter mehr in `choose`; `lineBudget` = 15.
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:240

### Runde 2
**Adversary:** Zeitzone und Tageswechsel in `dueWord`; Zehnerlauf echt?
**Implementierer:** `Calendar.current` im Testprozess nutzt die Host-Zeitzone, die der Simulator teilt; der Mitternachtsfall ist per UTC-Kalender in `testDueWordFollowsMidnight` belegt. Restfenster: `captured` wird vor `captureAndOpenDetail` gemerkt, die App rechnet "morgen" erst bei der Erfassung. Fällt Mitternacht genau dazwischen, erwartet der Test "Today", die App zeigt "Tomorrow" (F001, LOW).
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:250
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:113
Zehnerlauf: 10 Läufe, 10x "EXIT 0", alle "Executed 7 tests, with 0 failures", 0 übersprungen; simulator-run.txt: Passed, 7/7, Kopf 86d7f70. Diff-Statistik: nur LooseEndsUITests/FieldsSmokeTests.swift (+5/-4), keine App-Datei.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/FieldsSmokeTests.swift:107
  Description: `captured = Date()` wird vor `captureAndOpenDetail` gemerkt; die App wertet "morgen" erst zur Erfassungszeit aus.
  Spec requirement: AC-2 — Tageswechsel zwischen Erfassung und Lesen berücksichtigen
  Conflict: Mitternacht in den wenigen Sekunden zwischen Date() und App-Erfassung ergibt erwartet "Today", angezeigt "Tomorrow".
  Remediation: Optional `captured` nach dem Erfassen setzen; Fenster winziger als der behobene Fehler, kein Blocker.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/FieldsSmokeTests.swift:231
  Evidence: id-Button, waitForExistence, waitForNonExistence(15), danach waitUntil mit 15 s.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/FieldsSmokeTests.swift:251
  Evidence: startOfDay-Vergleich liefert Today/Tomorrow; testDueWordFollowsMidnight grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/FieldsSmokeTests.swift:104
  Evidence: adversary-test-output.txt 10x EXIT 0, simulator-run.txt Passed 7/7.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/FieldsSmokeTests.swift:229
  Evidence: Diff-Statistik: nur diese Datei, App-LoC 0.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 7 passed, 0 failed, 0 übersprungen (10 Läufe)
Edge cases: geprüft, nur F001 (LOW, winziges Mitternachtsfenster)
Regressions: None found
Checklist: 4/4 points proven

## Geprüfte Dateien

- sha256:9faf1afaebe2013dfe32086a325c1644e35b81b23e3a655c10261397e0568b5c  LooseEnds/Views/EditorPage.swift
- sha256:404b68120feef10c221ceab9478feb9d1bae9d744290e59458c3f81214149df9  LooseEndsUITests/FieldsSmokeTests.swift

## Prüfbasis

- base: 6d5153b05ca7fda9b2856e038f9bee3aa6f39160
- blob:a691518c942551f1e99de992f1d76385129a3daa  LooseEnds/Views/EditorPage.swift
- blob:fc4e21ad5ad7c30e063eaea5a1aea8c6613c9cb3  LooseEndsUITests/FieldsSmokeTests.swift
