# Validation Report: bug-165-wiederholend-test

Stand: 2026-10-02, Code-Stand 9ba2551 (PR #169).

## Test Results

- Unit-Suite (`./scripts/sim.sh unit`): 237 bestanden, 0 fehlgeschlagen (46 Suites)
- `./scripts/sim.sh test-proof CaptureSmokeTests` auf 9ba2551: 12/12 bestanden, Beleg `simulator-run.txt`
  (head 9ba2551, Prüfsumme der Testdatei passt). Zusammen mit den drei Läufen aus Phase 6 vier grüne Läufe
  mit aktivem Modell.
- Bildschirmaufnahmen (`testPlusButtonProof`) angesehen: Startseite mit allen Ansichten auf 0 →
  leeres Erfassungsfenster, „Done“ ausgegraut → „Reifen wechseln lassen“ eingetippt, „Done“ aktiv →
  Ansicht „New“ mit genau dieser Aufgabe.
- CI-Lauf 36984712575 (PR #169): Build, Unit und UI-Smoke grün.

## Spec Compliance

- AC-1, AC-2, AC-3, AC-4, AC-7, AC-8: erfüllt (Spec-Prüfung gegen den Diff, Adversary-Dialog VERIFIED)
- AC-5: erfüllt (siehe oben)
- **AC-6: für die Ursache von #165 erfüllt, im Wortlaut nicht.** Erster CI-Versuch: kein einziger
  Fehlschlag „Long press should open the menu“ mehr. In den 13 Läufen davor trat er in 9 auf, darunter
  `testDeletingRecurringTaskAfterCompletionDoesNotCrash` selbst (36860656065, 36454917913). Dieser Test
  war im ersten Versuch grün (70,5 s). Wiederholt wurde aber `testCalendarSwitchStaysOn`
  (`XCTAssertTrue failed - Value was Optional(0)`, Zeile 541). Dieser Test scheiterte schon vor #165 auf
  main (36828990111, 36826401134). Die Ursache ist eine andere und noch nicht geklärt, deshalb das eigene
  Ticket #170.
  PO-Entscheidung (Henning, 2026-10-02): #165 abschließen, Kalendertest als #170.

## Regression Check

- Keine Regressionen: Unit-Suite grün, alle UI-Testklassen in der CI grün, kein Produktcode berührt.

## Scope Check

- Code: 1 Datei (`LooseEndsUITests/CaptureSmokeTests.swift`, +100/−32), dazu `docs/project/04-stand.md`
- Keine Funktion über 50 Zeilen, keine Datei außerhalb der Spec
- Stufe 3: Kein Pfad der Geräteliste berührt.

## Folge-Issues (DoD)

- #170 UI-Test Kalenderschalter scheitert in der CI beim ersten Versuch
- #171 UI-Test Wiedererkennung findet Aufgabe über ihren Titel (`RecognitionWalkthroughTests`)
- #172 CI: Wiederholung fehlgeschlagener UI-Tests entfernen (blockiert durch #170)

## Result: PASS (AC-6 mit PO-Entscheidung)
