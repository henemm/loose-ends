---
entity_id: fix-443-faellig-wiederkehrend
type: bugfix
created: 2026-10-16
updated: 2026-10-16
status: draft
workflow: fix-443-faellig-wiederkehrend
---

# Spec: #443 Wiederkehrende Aufgaben stehen nicht unter „Fällig“, solange sie nicht fällig sind

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (#443): „Wiederkehrende Aufgaben erscheinen unter fällig, obwohl sie noch nicht fällig sind.“ Zwei Screenshots der Liste
„Fällig“: „Fußnagel behandeln“ (wöchentlich, fällig Mo 19.10.2026 19:00) und eine zweite Aufgabe mit „Mo“.

**Hat es bisher funktioniert?** Bis #455 (gemergt 2026-10-15) zeigte „Fällig“ absichtlich alles der nächsten 7 Tage; Henning hat das
am 2026-10-15 als Fehler benannt, #455 hat es auf „heute und überfällig“ geändert (`Shared/Models/ViewRules.swift`, `.due`). Beide
Screenshots zeigen ein Datum 19.10./„Mo“ und sind mit dem alten Vorlauf vollständig erklärbar. Alle TestFlight-Läufe vom 2026-10-16
liegen nach dem Merge von #455.

**Hypothese (unbewiesen):** #443 ist durch #455 bereits behoben. Gegenhypothese: ein Wiederholungs-Pfad setzt das Datum zu früh.
Beides entscheidet nur ein Lauf auf Hennings Weg (Simulator, App benutzt), nicht der Code. Der bestehende Test `DueTodayTests`
deckt „morgen nicht in Fällig“ auf Modellebene, aber nicht den Ablauf mit Wiederholung.

Diese Spec baut deshalb **zuerst die Nachstellung als Test** und entscheidet danach: Wird sie auf dem heutigen Stand sofort grün, ist
#443 durch #455 erledigt (Test bleibt als Schutz, kein Produktcode, Ticket mit Beleg schließen). Wird sie rot, wird die Ursache im
Wiederholungs-Pfad belegt und gezielt behoben.

Regelweg-Vermerk (Regeln vor Modell): reiner Datumsvergleich, kein Modell beteiligt.

## Lösung

1. **Nachstellung (RED/GREEN-Schalter), UI-Test** in `LooseEndsUITests/CaptureSmokeTests.swift`, Ablauf nach
   `testDeletingRecurringTaskAfterCompletionDoesNotCrash`: Aufgabe erfassen, Wiederholung „Weekly“ setzen, in „Wiederholend“ prüfen,
   abschließen, danach die Ansicht „Fällig“ öffnen. Erwartet: „Fällig“ enthält die Aufgabe nicht; „Wiederholend“ weiterhin.
2. **Modelltest** in der bestehenden `DueTodayTests`: wöchentliche Aufgabe, fällig morgen / in 7 Tagen / nach `TaskActions.complete`
   (Datum rollt um eine Woche) → in keinem Fall in `.due`; heute 19:00 und gestern → in `.due`.
3. **Nur bei rotem Test:** Fix im Wiederholungs-Pfad (`Shared/Models/RepeatRule.swift` oder `Shared/Services/TaskActions.swift`),
   Umfang < 30 LoC, Ursache zuvor mit dem roten Lauf belegt. Bei grünem Test entfällt Punkt 3 vollständig.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | neuer UI-Test: wöchentliche Aufgabe, abschließen, „Fällig“ leer, „Wiederholend“ zeigt sie |
| `LooseEndsTests/DueTodayTests.swift` | MODIFY | Fälle mit Wiederholungsregel |
| `Shared/Models/RepeatRule.swift` / `Shared/Services/TaskActions.swift` | NUR bei rotem Test | Datum zu früh gesetzt |

Geschätzt **+70 / −0 LoC** (Tests), bei Fehler +<30 Produktcode; innerhalb von ±250, höchstens 3 Dateien.

**Geräteliste (CLAUDE.md):** Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2 (Simulator).

**Side-Effects:** Keine Änderung an Datenmodell, Berechtigungen, Info.plist, AppStorage-Schlüsseln, Texten oder Audio.
`dueToday`/`NowTasks` (Startseite) haben eigene Regeln und bleiben unberührt.

### Nicht in diesem Ticket

- Die Regel von „Fällig“ selbst (bleibt: heute und überfällig, #455).
- Startseite (`NowTasks`, `badgeCount`).
- Ein Vorlauf-Schalter für „Fällig“ (neue Funktion, nicht verlangt).

## Test Plan

### Automated Tests (TDD RED zuerst)

- UI-Test (siehe Lösung 1) im Simulator mit `./scripts/sim.sh test-proof CaptureSmokeTests`; sein erster Lauf auf dem heutigen Stand
  ist die Nachstellung. Das Ergebnis (grün oder rot) wird als Beleg im Ticket festgehalten.
- `DueTodayTests`: wiederkehrende Aufgabe fällig morgen und in 7 Tagen → nicht in `.due`; nach `complete` → nicht in `.due`;
  fällig heute 19:00 und gestern → in `.due`.

### Abnahme (Stufen)

1. **Tests:** `./scripts/sim.sh sim-unit` grün (nie auf dem Mac als Host).
2. **Simulator:** `./scripts/sim.sh generate`, `build`, `test-proof CaptureSmokeTests`; Screenshot von „Fällig“ (leer) und
   „Wiederholend“ (Aufgabe sichtbar) geöffnet und beschrieben.
3. **Gerät:** entfällt. „Kein Pfad der Geräteliste berührt.“

## Acceptance Criteria

- **AC-1:** Given eine wöchentlich wiederkehrende Aufgabe, die nach heute fällig ist (morgen, in 7 Tagen oder nach dem Abschließen
  eine Woche weiter) / When `ViewRules.tasks(for: .due, …)` gebildet wird / Then enthält die Liste die Aufgabe nicht. Belegt durch
  Unit-Test in `DueTodayTests`.
- **AC-2:** Given eine wiederkehrende Aufgabe fällig heute 19:00 oder gestern / When `.due` gebildet wird / Then ist sie enthalten
  (die Regel von #455 bleibt). Belegt durch Unit-Test.
- **AC-3:** Given im Simulator eine neu erfasste Aufgabe mit Wiederholung „Weekly“, einmal abgeschlossen / When die Ansicht „Fällig“
  geöffnet wird / Then zeigt sie die Aufgabe nicht, und „Wiederholend“ zeigt sie weiterhin. Belegt durch UI-Test samt Screenshots.
- **AC-4:** Given der UI-Test aus AC-3 läuft auf dem unveränderten Stand / When er rot wird / Then ist die Ursache im
  Wiederholungs-Pfad mit diesem Lauf belegt und nach dem Fix derselbe Lauf grün; wird er sofort grün, ist #443 durch #455
  erledigt und das Ticket mit diesem Beleg geschlossen, ohne Änderung an Produktcode.

## Risiken

- **Test-Aufbau verschiebt den Ausgangszustand (mittel):** Ein Test, der sich Daten selbst herstellt, prüft nur den halben Weg
  ([[feedback-use-the-app-not-just-build-it]]). Gegenmittel: der UI-Test benutzt den echten Bedienweg (Erfassen, Editor, Abschluss
  per Menü), keine vorgesetzten Datumswerte.
- **Simulator-Eigenheit (niedrig):** Der iOS-27-Simulator hat ein Modell, das Felder überschreiben kann (#208); die Fälligkeit setzt
  hier die Regel, daher unkritisch.
- **Kein Fehler reproduzierbar (niedrig):** Dann wird das Ticket mit Beleg geschlossen; Hennings Screenshots bleiben durch den alten
  Vorlauf erklärt. Meldet er es nach dem nächsten Build erneut, folgt ein neues Ticket mit Datum/Build.

## Alternativen

- **Nur schließen, ohne eigenen Test** (Beleg: `DueTodayTests`, Datumsvergleich). Verworfen: Der Ablauf mit Wiederholung im echten
  Lauf ist nirgends geprüft. Kein ADR wird gekippt.
- **Vorlauf in „Fällig“ als Einstellung** (heute / 7 Tage wählbar): löst nicht den gemeldeten Fehler, ist neue Funktion. Nicht
  vorgeschlagen; würde die Festlegung aus #455 aufweichen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Es ändert sich keine Architektur; geprüft wird die bestehende Regel von „Fällig“ (#455) gegen den Ablauf
  mit Wiederholung, im Fehlerfall ein Datumsfehler im Wiederholungs-Pfad.

## Offene Fragen

- Keine für Henning.

## Source

- **Datei:** `Shared/Models/ViewRules.swift`
- **Identifier:** `ViewRules.tasks(for: .due, …)` (Regel „heute und überfällig“); Wiederholungs-Pfad: `TaskActions.complete`,
  `RepeatRule.nextDueDate(previousDue:completedOn:)`

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `ViewRules.tasks(for: .due)` | speist Seitenleiste (`SidebarView`, Zähler) und Liste (`TaskListView`) |
| `TaskActions.complete` / `RepeatRule.nextDueDate` | rollt das Datum nach dem Abschluss vor |
| #455 | Voraussetzung, schon auf main (Regel „Fällig“ = heute und überfällig) |
| `CaptureSmokeTests.swift` (Hilfen `launch`, `element`, `revealField`) | Vorlage und Hilfen für den UI-Test |

## Definition of Done

- AC-1 bis AC-4 erfüllt; neue Tests grün (bei Fehlerfall zuerst rot belegt); alle bestehenden Tests grün.
- Screenshots „Fällig“ und „Wiederholend“ aus dem Simulator geöffnet und beschrieben.
- Ticket #443 mit dem Beleg geschlossen (`Closes #443` im PR); Board auf Done.
- Abschlussbericht ohne Git-Vokabular: Wiederkehrende Aufgaben stehen erst am Tag ihrer Fälligkeit unter „Fällig“; der Ablauf ist
  nun im Simulator geprüft. Satz: „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-16: Initiale Spec für #443.
