# Adversary Dialog — feat-1000-neu-entfaellt
Spec: docs/specs/feat-1000-schnitt-1-startseite-ohne-neu.md
Datum: 2026-11-26 14:13

## Checkliste
- [x] **AC-1:** Nach Return in der Schreibzeile gibt es auf der Startseite kein Element `inboxBar` und keinen Text „zum Durchsehen“/„to look over“; die Zeile dieser Sitzung steht oberhalb der Schreibzeile (Tests 6, 7, 10; iPhone und Mac).
- [x] **AC-2:** `ViewRules.dailyViews` und `ViewRules.indexViews(in:)` enthalten `.new` nicht; der Index („Inhalt“) und die Seitenleiste auf iPad und Mac führen „Neu“ nicht (Tests 1, 2, 3, 9).
- [x] **AC-3:** Eine über die Schreibzeile erfasste Aufgabe steht sofort in „Lose Enden“ und, wenn sie „heute“ sagt, auch in „Jetzt“; der UI-Test öffnet sie von dort (Tests 4, 8).
- [x] **AC-4:** Die Ansage nach Return lautet in en „Captured: %@“ und in de „Aufgenommen: %@“; der Katalog enthält „Filed in New: %@“ nicht mehr (Test 5).
- [x] **AC-5:** Alle UI-Tests, die bisher über `viewRow_new` gingen, bestehen über den neuen Weg; kein UI-Test nennt `viewRow_new` oder `inboxBar` außer in einer Abwesenheitsprüfung (Tests 11, 12).
- [x] **AC-6:** Simulatordurchlauf auf dem iPhone: ein Satz getippt, Return, die Aufgabe steht in ihrer Liste; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshots der Startseite geöffnet und beschrieben (Tests 6 bis 8).

## Dialog

### Runde 1
**Adversary:** Diff gelesen (3 App-Dateien). Beweise je AC gefordert. Quelle ist seit 12:25 unveraendert, Unit-/UI-Belege (12:29 ff.) stammen vom aktuellen Stand. Katalogwaechter selbst neu gelaufen: 9 Tests OK. Screenshots geoeffnet: s1-erste-zeile (Zeile "Reifen wechseln" ueber der Schreibzeile, kein Kopf "New", Index: Next up, Due, Tags, Projects, kein New), s1-zugeklappt (Jetzt 1: "Mama anrufen" heute; Index mit "All open 2", Completed, kein New), s1-lose-enden ("All open" mit beiden Aufgaben).
**Implementierer:** Belege test-green-output.txt, unit-*.txt, ui-*.txt.

### Runde 2
**Adversary:** Edge Cases: (a) SavedView mit kind .new: ViewKind.new, TaskListView-Pfade (:120, :247, :593) unveraendert, nur ueber gespeicherte Ansicht erreichbar, laut Spec Schnitt 2/3. (b) iPad-Seitenleiste: SidebarView nutzt ViewRules.indexViews (SidebarView.swift:79), damit ohne .new; UI-Abwesenheitspruefung StartScreenInteractionTests:547 (laeuft im 17/17-Lauf gruen). (c) ui-smoke-lang: Phrase lookOver nur noch in Abwesenheitspruefung InboxDrawerSmokeTests:41 und LaunchLanguage:32 (Phrase bleibt definiert, wird nur negativ benutzt; unkritisch). (d) VoiceOver-Ansage: Katalogschluessel en/de per Wächter belegt, Ansage selbst nicht per Test gelesen (laut Spec nur Katalog). (e) Nachlauf: "Nothing to look over." / "%lld to look over" bleiben im Katalog (Schnitt 3, laut Spec). (f) AC-5 Lücke: Hintergrundlauf der uebrigen umgestellten Klassen ist nicht abgeschlossen (ui-rewired-summary.txt leer, nur CalendarTargetTests gestartet, ohne Ergebnis). Lokal belegt: CaptureSmokeTests 29/29, StartScreenInteractionTests 17/17 (3 per Einzelwiederholung), InboxDrawerSmokeTests 2/2. Unbelegt lokal: Calendar, ContextUniqueness, DesignGallery, Fields, Drive, ProjectSubtasks, Paper, NoModelCapture, Recognition, Place, StoreScreenshots; Mac-Klassen nur per Code-Pfad (CI-Nachweis "Mac Gallery (macOS)"). Grep zeigt in allen UI-Tests viewRow_new/inboxBar nur noch in XCTAssertFalse-Abwesenheitspruefungen.
**Implementierer:** Rest laeuft im CI.

### Runde 3
**Adversary:** F001 neu bewertet. ui-rewired-summary.txt endet mit DONE, alle Klassen rc=0, Einzelzeilen in ui-<Klasse>.txt selbst gelesen: Calendar 3/3, ContextUniqueness 1/1, Drive 4/4, Fields 7/7, NoModelCapture 1/1, Place 7/7, ProjectSubtasks 1/1, Recognition 1/1, StoreScreenshots 1/1, DesignGallery 1/1, je 0 Fehler. Uebersprungen, einzeln benannt: PaperGroundTests, beide Tests (iPad-only, XCTSkipUnless .pad; Umstellung ist die eine Zeile PaperGroundTests.swift:104 viewRow_open). Nicht lokal beweisbar: Mac-Klassen (CI "Mac Gallery (macOS)"), PaperGround auf iPad. Beides ist durch Branch-Schutz vor dem Merge erzwungen und kein Code-Widerspruch.
**Implementierer:** F001 erledigt bis auf CI-Nachweis.

### Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/InboxDrawerView.swift:42
  Evidence: body-VStack zeigt nur Zeilen und Schreibzeile, head/count/headGlow/glowHead entfernt; Screenshot s1-erste-zeile, InboxDrawerSmokeTests 2/2, StartScreenInteractionTests:202 (iPhone); Mac per Code-Pfad (MacDetailClickTests:340, CI-Nachweis)
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Models/ViewRules.swift:53
  Evidence: dailyViews = [.next, .due], indexViews (:67) beginnt mit [.next, .due]; StartViewsTests gruen; Index-Screenshots ohne New
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/InboxDrawerView.swift:128
  Evidence: CaptureService.save unveraendert; Screenshot s1-lose-enden und s1-zugeklappt (Jetzt 1 fuer heute-Aufgabe); InboxDrawerTests gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/InboxDrawerView.swift:131
  Evidence: Announcement "Captured: %@"; Katalog de "Aufgenommen: %@", "Filed in New: %@" weg; Waechter test_catalog_languages 9 OK (selbst gelaufen)
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Models/ViewRules.swift:67
  Evidence: alle umgestellten iOS-UI-Klassen gruen (Runde 3); viewRow_new/inboxBar nur in Abwesenheitspruefungen; PaperGround (iPad) und Mac-Klassen als CI-Nachweis benannt
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/InboxDrawerView.swift:42
  Evidence: test-proof InboxDrawerSmokeTests 2/2 (test-proof-InboxDrawerSmokeTests.txt, simulator-run.txt), drei Screenshots geoeffnet und beschrieben
  Status: CONFIRMED

### Findings

Finding:
  ID: F001 (Runde 3: erledigt, lokal alle iOS-Klassen gruen; Rest CI)
  Severity: LOW
  Category: spec_violation
  Code reference: Shared/Models/ViewRules.swift:53
  Description: Die Aenderung am Code ist korrekt, aber AC-5 ist lokal nicht vollstaendig belegt: der Hintergrundlauf der uebrigen elf umgestellten iOS-UI-Klassen hat keine Ergebnisse (ui-rewired-summary.txt leer, ui-CalendarTargetTests.txt ohne Ergebnis).
  Spec requirement: AC-5 — alle bisherigen UI-Tests bestehen ueber den neuen Weg
  Conflict: Fuer diese Klassen fehlt ein gruener Lauf; Mac-Klassen nur per CI beweisbar.
  Remediation: Hintergrundlauf bis DONE abwarten und Ergebnisse pruefen oder CI-Lauf (ui-smoke, Mac Gallery) als Nachweis abwarten.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
AC-1 bis AC-6 bewiesen. Tests: alle lokalen Laeufe 0 Fehler, 2 uebersprungen (PaperGroundTests, iPad-only). Mac-Klassen und iPad-Lauf sind CI-Nachweis (Branch-Schutz).

## Geprüfte Dateien

- sha256:feaaedb308244e7220f24fb74b32bd4c86b76d20d3444b35fa739168132a8db4  LooseEnds/Views/InboxDrawerView.swift
- sha256:4e1b8645f111c8ab80f43a4b9eabea36cb28e46d9d8ac93245b7e418f1fe0ab7  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 84dbca05adb61a445c441c299d66151ea2a5bb37
- blob:fcea3c26725c76bc2a04287c5915ddf0b6b45589  LooseEnds/Views/InboxDrawerView.swift
- blob:d640e662ef291396811cc2d664e5aa385c2cc8a2  Shared/Models/ViewRules.swift

## Geprüfte Dateien

- sha256:feaaedb308244e7220f24fb74b32bd4c86b76d20d3444b35fa739168132a8db4  LooseEnds/Views/InboxDrawerView.swift
- sha256:4e1b8645f111c8ab80f43a4b9eabea36cb28e46d9d8ac93245b7e418f1fe0ab7  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 84dbca05adb61a445c441c299d66151ea2a5bb37
- blob:fcea3c26725c76bc2a04287c5915ddf0b6b45589  LooseEnds/Views/InboxDrawerView.swift
- blob:d640e662ef291396811cc2d664e5aa385c2cc8a2  Shared/Models/ViewRules.swift
