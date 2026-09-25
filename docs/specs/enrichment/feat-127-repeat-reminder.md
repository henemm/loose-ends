---
entity_id: feat-127-repeat-reminder
type: feature
created: 2026-09-25
updated: 2026-09-25
status: draft
workflow: feat-127-repeat-reminder
---

# Spec: #127 — Implizites erstes Fälligkeitsdatum für neu angelegte Wiederholungsregeln

## Approval

- [ ] Approved

## Purpose

Eine frisch angelegte reine Wiederholung („Jeden Tag um 7 Uhr die Tabletten nehmen") hat noch kein
`dueDate` und bekommt deshalb nie eine Erinnerung: `DueReminders.plan` bricht bei Tasks ohne
`dueDate` ohnehin ab (`Shared/Notifications/DueReminders.swift`, Zeile 33). PO-Entscheidung aus der
Intake-Klärung (2026-09-24, nicht mehr zu hinterfragen): Beim Neuanlegen einer `RepeatRule` wird
sofort ein implizites erstes `dueDate` gesetzt, statt `DueReminders` um eine von `dueDate`
losgelöste Planungslogik zu erweitern. Das ist derselbe Schnittpunkt, den #102 bereits verändert
hat (dort wurden `hour`/`minute` auf `RepeatRule` eingeführt; #127 ist dort explizit als
Folgeticket benannt, siehe `docs/specs/enrichment/rule-102-repeat-time.md`, Abschnitt
„Alternativen"). `dueDate` bleibt dabei ein Enrichment-Feld mit eigener `RevisedField`-Historie
(ADR-3) — nur der Auslöser dieser einen Schreiboperation ist eine manuelle User-Handlung im Editor,
genau wie bei jeder anderen Freihandänderung des Fälligkeitsdatums über `setDue`.

## Source

- **Datei:** `Shared/Models/RepeatRule.swift`
- **Bezeichner:** `struct RepeatRule`, `func firstDueDate(now:calendar:)` (neu)
- **Datei:** `LooseEnds/Views/FieldEditorView.swift`
- **Bezeichner:** `private func applyRepeat(_ rule: RepeatRule?)` (Zeile 227-229)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `RepeatRule.nextDueDate(previousDue:completedOn:calendar:)` (Zeile 19-43) | Wiederverwendung | Liefert bei `previousDue: nil` den ersten Termin ab `now` (fällt intern auf `completedOn` zurück, Zeile 21: `previousDue ?? completedOn`). `firstDueDate` ist ein dünner Aufsatz darauf, keine neue Terminberechnung. |
| `RepeatRule.hour`/`.minute` (aus #102) | Wiederverwendung | Bestimmen, ob `firstDueDate` eine konkrete Uhrzeit trägt oder auf `startOfDay` zurückfällt — dasselbe Signal, das #102 bereits aus dem Rohtext vorbefüllt. |
| `LooseEnds/Views/FieldEditorView.swift`, `private func setDue(_ date:hasTime:)` (Zeile 234-239) | Wiederverwendung | Bestehender, einziger Schreibpfad für `dueDate` im Editor: schreibt über `RevisionService.set(.dueDate, …)` mit `author: .user` und setzt `task.dueHasTime` korrekt. Wird unverändert wiederverwendet, nicht dupliziert. |
| `Shared/Notifications/DueReminders.swift`, `plan(for:hour:now:calendar:)` (Zeile 26-39) | Downstream, unangetastet | Bricht bei `task.dueDate == nil` ab (Zeile 33) — sobald ein `dueDate` existiert, greift die bestehende Logik automatisch. `hour` ist dort ein einziger globaler Parameter (Default 9, Zeile 9) für alle Aufgaben: die „Heute fällig"-Mitteilung ist ein täglicher Sammel-Push um 9 Uhr, kein individueller Reminder zur `repeatRule.hour`/`.minute`-Zeit. |
| `Shared/Models/ViewRules.swift`, `.due`/`.repeating` | Downstream, unangetastet | `.due` filtert auf `dueDate <= now + 7 Tage`; `.repeating` zeigt jede Aufgabe mit `repeatRule != nil` unabhängig von `dueDate` — beide unverändert. |
| `Shared/Services/CalendarSync.swift` | Downstream, unangetastet | Prüft `task.dueHasTime` für Ganztag- vs. Uhrzeit-Termin — reiner Mitnahme-Effekt, weil `dueHasTime` korrekt aus `rule.hour != nil` abgeleitet wird (über `setDue`). |
| `Shared/Services/TaskActions.swift`, `complete(_:now:calendar:)` (Zeile 13-19) | Abgrenzung, unangetastet | Übernimmt nach dem ersten Abhaken weiterhin die Folgetermine (`task.dueDate = rule.nextDueDate(...)`, Zeile 17, ohne `RevisionService`) — unabhängig davon, ob das erste `dueDate` implizit oder vom User gesetzt wurde. Nicht Teil dieses Tickets. |
| `docs/specs/enrichment/rule-102-repeat-time.md` | Ursprungsspec | Benennt #127 explizit als Folge-Issue („Reminder für reine Wiederholungen ohne Fälligkeitsdatum") und legt `hour`/`minute` als Nicht-Enrichment-Felder fest — diese Festlegung bleibt unverändert, nur `dueDate` selbst wird hier geschrieben. |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Models/RepeatRule.swift` | MODIFY | Neue reine, kontextfreie Funktion `func firstDueDate(now: Date = .now, calendar: Calendar = .current) -> Date`, direkt neben `nextDueDate`. Nutzt `nextDueDate(previousDue: nil, completedOn: now, calendar: calendar)` für den ersten Termin und setzt, falls `hour`/`minute` vorhanden sind, die Uhrzeit über `calendar.date(bySettingHour:minute:second:of:)`; sonst `calendar.startOfDay(for:)`. |
| `LooseEnds/Views/FieldEditorView.swift` | MODIFY | `applyRepeat(_:)` (Zeile 227-229): nach dem bestehenden `apply(...)`-Aufruf ein Guard `isNewRule && task.dueDate == nil`, das bei Erfüllung `setDue(rule.firstDueDate(), hasTime: rule.hour != nil)` aufruft. `setDue` (Zeile 234-239) bleibt unverändert. |
| `LooseEndsTests/RepeatRuleTests.swift` | MODIFY | Neue Testfälle für `firstDueDate` (TDD RED zuerst): mit erkannter Uhrzeit, ohne erkannte Uhrzeit, wöchentliche Regel ohne `weekdays`. |
| `LooseEndsTests/RepeatEditTests.swift` | MODIFY | Neue Testfälle, die den Schreibablauf aus `applyRepeat` nachstellen (analog zum bestehenden Muster für `RepeatRule.selecting` aus #102): Neuanlage ohne `dueDate`, Neuanlage mit bereits gesetztem `dueDate`, nachträgliche Regeländerung ohne erneuten Prefill. |

**Geschätzter Umfang:** 4 Dateien (2 Produktionsdateien, 2 Testdateien), ca. +80 bis +110 LoC
insgesamt (Modell-Funktion ~8 LoC, View-Anbindung ~10 LoC, Tests ~60-90 LoC) — deutlich unter der
250-LoC-Grenze und innerhalb der 4–5-Dateien-Richtgröße aus CLAUDE.md. Risk Level: LOW. Kein Split
nötig.

## Implementation Details

**`RepeatRule.firstDueDate(now:calendar:)` ist eine reine, kontextfreie Funktion**, ohne eigene
Terminlogik — sie kombiniert ausschließlich bereits bestehende Bausteine:

```swift
func firstDueDate(now: Date = .now, calendar: Calendar = .current) -> Date {
    let next = nextDueDate(previousDue: nil, completedOn: now, calendar: calendar)
    guard let hour, let minute else { return calendar.startOfDay(for: next) }
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: next) ?? next
}
```

Sie hat keine Abhängigkeit von SwiftData oder der View-Schicht und ist direkt unit-testbar. Mit
`previousDue: nil` liefert `nextDueDate` (Zeile 21: `previousDue ?? completedOn`) den ersten Termin
relativ zu `now` — dasselbe Verhalten, das `nextDueDate` bereits für Folgetermine nutzt, hier nur
ohne vorherigen Fälligkeitstermin als Anker.

**Geschrieben wird ausschließlich in `FieldEditorView.applyRepeat`, nicht in der
Picker-Closure `repeatControl` selbst.** Per `grep -rn "repeatRule"` über `Shared/` und `LooseEnds/`
(ohne Tests) verifiziert: `applyRepeat` (Zeile 227-229) ist der einzige produktive Schreibpfad für
`repeatRule` im gesamten Projekt — der einzige Instanziierungsort einer `RepeatRule` ist
`TaskDetailView.swift:130`, kein AI-Enrichment-Pfad existiert dafür. `applyRepeat` wird von allen
vier Editor-Controls aufgerufen (Frequenz-Picker, Interval-Stepper, Wochentag-Zeile,
Basis-Picker, Zeilen 169/184/196/217), daher genügt eine einzige Änderungsstelle:

```swift
private func applyRepeat(_ rule: RepeatRule?) {
    let isNewRule = task.repeatRule == nil && rule != nil
    apply(rule.flatMap(FieldCodec.encode))
    if isNewRule, let rule, task.dueDate == nil {
        setDue(rule.firstDueDate(), hasTime: rule.hour != nil)
    }
}
```

**Der Schreibguard ist zweiteilig: `isNewRule && task.dueDate == nil`.** `isNewRule` allein würde
nicht reichen: Hat der User bereits manuell ein `dueDate` gesetzt, bevor er eine Wiederholung
hinzufügt, darf `firstDueDate` es nicht überschreiben. Beide Teile werden vor dem bestehenden
`apply(...)`-Aufruf ausgewertet (der `task.repeatRule` verändert), damit `isNewRule` den Zustand
*vor* der Mutation festhält.

**Geschrieben wird über das bestehende `setDue` (Zeile 234-239), unverändert.** `setDue` schreibt
korrekt über `RevisionService.set(.dueDate, …)` mit `author: .user` und setzt `task.dueHasTime`
passend zum `hasTime`-Parameter — dasselbe Muster, das der Editor bereits für jede Freihandänderung
des Datums nutzt (`dueControl`, Zeile 68-85). Es wird **nicht** der direkte Zuweisungsstil aus
`TaskActions.complete` (Zeile 17: `task.dueDate = rule.nextDueDate(...)` ohne `RevisionService`)
übernommen, weil `dueDate` laut #102-Spec ein Enrichment-Feld mit eigener `RevisedField`-Historie
bleibt (im Unterschied zu `repeatRule.hour`/`.minute`, die kein Enrichment-Feld sind) — nur der
Auslöser (eine Editor-Aktion) ist hier eine manuelle User-Handlung.

**`DueReminders.plan`, `DueDateRule`, `DateExpressionParser.isRepetition` und
`ViewRules` bleiben komplett unangetastet.** Sie lesen ausschließlich `task.dueDate`, unabhängig
davon, wie es zustande kam — kein neuer Codepfad, der dort brechen könnte.

## Test Plan

### Automated Tests (TDD RED)

**Neu/Geändert in `LooseEndsTests/RepeatRuleTests.swift`**
- GIVEN eine `RepeatRule` mit `frequency: .daily, hour: 19, minute: 0` und `now` = heute 08:00 Uhr
  / WHEN `firstDueDate(now:calendar:)` aufgerufen wird / THEN liefert sie morgen 19:00 Uhr — die
  über `nextDueDate` berechnete nächste Periode, kombiniert mit der gesetzten Uhrzeit (AC-1).
- GIVEN eine `RepeatRule` mit `frequency: .weekly, weekdays: nil` und ohne `hour`/`minute` / WHEN
  `firstDueDate(now:calendar:)` aufgerufen wird / THEN liefert sie den `startOfDay` des von
  `nextDueDate` berechneten Termins (AC-1).
- GIVEN eine `RepeatRule` mit `frequency: .weekly, weekdays: nil` (kein Wochentag gesetzt) / WHEN
  `firstDueDate` aufgerufen wird / THEN entspricht das Ergebnis exakt
  `nextDueDate(previousDue: nil, completedOn: now, calendar: calendar)` — belegt, dass der
  bestehende „+7×interval Tage"-Rückfall von `nextDueDate` unverändert durchgereicht wird, kein
  neuer Sonderfall (AC-1, Risiko 3).

**Neu in `LooseEndsTests/RepeatEditTests.swift`**
- GIVEN eine Aufgabe ohne `repeatRule` und ohne `dueDate` / WHEN der Schreibablauf aus
  `applyRepeat` nachgestellt wird (Guard auswerten, `RevisionService.set(.repeatRule, …)`, dann bei
  erfülltem Guard `RevisionService.set(.dueDate, to: rule.firstDueDate().ISO8601Format(), …)` plus
  `task.dueHasTime = rule.hour != nil`) / THEN trägt `task.dueDate` den Wert von `firstDueDate()`,
  `task.dueHasTime` ist korrekt abgeleitet, und es existiert eine `Revision` mit `field == .dueDate`
  und `author == .user` (AC-2).
- GIVEN eine Aufgabe ohne `repeatRule`, aber mit bereits manuell gesetztem `dueDate` / WHEN
  derselbe Ablauf für eine neu gewählte Regel durchläuft / THEN bleibt `task.dueDate` unverändert
  — kein `.dueDate`-Revision-Eintrag entsteht durch diesen Schritt (AC-3).
- GIVEN eine Aufgabe mit bereits bestehender `repeatRule` und gesetztem `dueDate` / WHEN Frequenz,
  Intervall, Wochentage oder Basis dieser Regel geändert werden (der Guard `isNewRule` ist dann
  `false`) / THEN bleibt `task.dueDate` unverändert — kein erneuter Aufruf von `firstDueDate` (AC-4).

**Entfallend**
- Keine.

**Unverändert grün (Regressionsbeleg)**
- `LooseEndsTests/RepeatRuleTests.swift` und `LooseEndsTests/RepeatEditTests.swift`, alle
  bestehenden Fälle aus #102 (`timeGuess`, `selecting`, Codec-Round-Trip): unverändert grün, da
  `firstDueDate` ein rein additiver neuer Baustein ist (AC-6).
- `LooseEndsTests/DueRemindersTests.swift` (falls vorhanden) bzw. die bestehende Testabdeckung von
  `DueReminders.plan`: unverändert grün, da `plan` selbst nicht verändert wird (AC-6).
- Neuer Fall als Downstream-Beleg: GIVEN eine Aufgabe mit `repeatRule` und einem über
  `firstDueDate()` gesetzten `dueDate` in der Vergangenheit relativ zum Reminder-Zeitpunkt / WHEN
  `DueReminders.plan(for:hour:now:calendar:)` mit dieser Aufgabe aufgerufen wird / THEN enthält das
  Ergebnis einen `Reminder` für diese Aufgabe — belegt, dass die Aufgabe automatisch, ohne
  Änderung an `DueReminders`, in den 9-Uhr-Sammel-Push aufgenommen wird (AC-5).

Kein neuer UI-Test: Es entsteht keine neue View, kein neues Steuerelement — reine Erweiterung
bestehender Datenlogik hinter den vier bereits existierenden Editor-Controls. Das Projekt schreibt
UI-Tests erst nach dem Design-Freeze und nur als Smoke-Tests (CLAUDE.md).

## Acceptance Criteria

- **AC-1 `firstDueDate` berechnet Datum und optional Uhrzeit korrekt:** Given eine `RepeatRule` mit
  gesetzter `hour`/`minute` / When `firstDueDate(now:calendar:)` aufgerufen wird / Then trägt das
  Ergebnis den von `nextDueDate` berechneten Termin mit der gesetzten Uhrzeit; given eine
  `RepeatRule` ohne `hour`/`minute` / Then liefert sie den `startOfDay` desselben Termins; given
  eine wöchentliche Regel ohne `weekdays` / Then entspricht das Ergebnis unverändert dem
  bestehenden Rückfallverhalten von `nextDueDate`.
- **AC-2 Implizites `dueDate` bei Neuanlage einer Regel ohne bestehendes Fälligkeitsdatum:** Given
  eine Aufgabe ohne `repeatRule` und ohne `dueDate` / When der User im `FieldEditorView` erstmals
  eine Wiederholungsregel anlegt / Then trägt `task.dueDate` den Wert von `rule.firstDueDate()`,
  `task.dueHasTime` ist korrekt aus `rule.hour != nil` abgeleitet, und es existiert eine `Revision`
  mit `field == .dueDate` und `author == .user`.
- **AC-3 Kein Überschreiben eines bereits gesetzten `dueDate`:** Given eine Aufgabe ohne
  `repeatRule`, aber mit einem bereits manuell gesetzten `dueDate` / When der User eine
  Wiederholungsregel anlegt / Then bleibt `task.dueDate` unverändert.
- **AC-4 Kein erneuter Prefill bei bestehender Regel:** Given eine Aufgabe mit bereits bestehender
  `repeatRule` und gesetztem `dueDate` / When der User Frequenz, Intervall, Wochentage oder Basis
  dieser Regel ändert / Then bleibt `task.dueDate` unverändert — `firstDueDate` wird nicht erneut
  aufgerufen.
- **AC-5 Downstream-Wirkung im täglichen Sammel-Push (kein individueller Reminder):** Given eine
  Aufgabe mit `repeatRule` und einem über `firstDueDate()` implizit gesetzten `dueDate` / When
  `DueReminders.plan(for:hour:now:calendar:)` mit dieser Aufgabe aufgerufen wird / Then erscheint
  die Aufgabe im Ergebnis, sobald ihr Fälligkeitsdatum erreicht ist — als Teil des einen täglichen
  9-Uhr-Sammel-Pushs, nicht als individueller Reminder zur `repeatRule.hour`/`.minute`-Zeit.
- **AC-6 Regression:** Given `./scripts/sim.sh unit` / When der Testlauf ausgeführt wird / Then
  bleiben alle bestehenden Testfälle aus #102 (`RepeatRuleTests`, `RepeatEditTests`) sowie die
  bestehende Testabdeckung von `DueReminders.plan` unverändert grün.

## Risiken

1. **Erwartungslücke Uhrzeit:** Die tägliche Mitteilung feuert einheitlich um 9 Uhr, nicht exakt
   zur `repeatRule.hour`-Zeit. Gegenmaßnahme: in AC-5 explizit benannt, damit später nicht wie ein
   neuer Bug wirkt — ein individueller Reminder-Zeitpunkt pro Aufgabe ist eine in der
   Intake-Klärung ausdrücklich verworfene Alternative (siehe Nicht-Scope).
2. **Kein erneuter Prefill bei bestehender Regel und kein Überschreiben eines bereits gesetzten
   `dueDate`:** Beide Fälle sind über den zweiteiligen Guard `isNewRule && task.dueDate == nil`
   abgedeckt und durch AC-3/AC-4 mit je einem eigenen Testfall belegt.
3. **Wochentag-lose wöchentliche Regel:** `nextDueDate` fällt ohne `weekdays` auf „+7×interval
   Tage" zurück — bestehendes, unverändertes Verhalten, kein neuer Sonderfall; durch einen eigenen
   Testfall in AC-1 explizit belegt statt nur behauptet.
4. **`dueHasTime`-Kopplung:** Wird nur gesetzt, wenn `repeatRule.hour != nil`, sonst greift das
   bestehende Muster „Datum ohne Zeit → `startOfDay`" aus `setDue` — bereits im `applyRepeat`-Code
   (`hasTime: rule.hour != nil`) und in AC-1/AC-2 abgedeckt.
5. **Kein „heute", nur „+1 Periode":** `nextDueDate` springt bei täglichen Regeln immer auf den
   nächsten Zyklus, auch wenn die erkannte Uhrzeit heute noch bevorsteht (Regel „jeden Tag um 19
   Uhr" morgens angelegt → erstes `dueDate` liegt auf morgen 19 Uhr, nicht heute 19 Uhr).
   Bestehendes, unverändertes Verhalten von `nextDueDate` — explizit in AC-1 (erster Testfall)
   benannt, damit es später nicht wie ein neuer Bug wirkt.
6. **Bestandsdaten bleiben unversorgt:** Aufgaben mit `repeatRule`, aber ohne `dueDate`, die schon
   vor diesem Fix angelegt wurden (exakt der im Issue geschilderte Fall), bekommen den Fix nicht
   rückwirkend — nur ein erneutes Anfassen der Regel im Editor löst ihn aus. Gegenmaßnahme: bewusst
   außerhalb der DoD dieses Tickets, siehe Nicht-Scope; keine rückwirkende Migration.
7. **Zwei `save()`-Aufrufe statt einem:** `apply()` speichert bereits, `setDue` speichert erneut —
   funktional unproblematisch (kein Korrektheitsrisiko), aber zwei CloudKit-Push-Zyklen für eine
   logische Aktion. Keine Pflicht zur Behebung in diesem Scope, nur als bekanntes Risiko benannt.

## Alternativen

- **Ein `didSet`/Setter-Wrapper direkt auf `TaskItem.repeatRule`**, der bei jedem Übergang
  nil→non-nil automatisch ein `dueDate` primt: robuster gegen einen künftigen zweiten Schreibpfad
  (z. B. AI-Enrichment). Verworfen, weil dies die Festlegung aus
  `docs/specs/enrichment/rule-102-repeat-time.md` kippen würde, dass `repeatRule` rein manuell
  gesetzt wird, und die Grenze zwischen Datenhaltung und Editor-Geschäftslogik auflösen würde
  (Bruch mit dem Revision-Muster: Feld-Schreiblogik mit Nutzer-Intent gehört in den
  Service-/View-Layer, nicht ins Modell). Da aktuell nachweislich nur ein einziger Schreibpfad für
  `repeatRule` existiert (per `grep` verifiziert), ist der Zusatzaufwand nicht gerechtfertigt.
- **`DueReminders` um eine von `dueDate` losgelöste Planungslogik erweitern** (Reminder direkt aus
  `repeatRule.hour`/`.minute` ableiten, ganz ohne implizites `dueDate`): war die ursprünglich
  naheliegende Alternative, in der Intake-Klärung vom PO (2026-09-24) explizit zugunsten des
  gewählten Wegs verworfen — sie hätte einen zweiten, parallelen Planungspfad in `DueReminders`
  geschaffen, während der gewählte Weg die bestehende, bereits getestete `dueDate`-Logik
  wiederverwendet. Nur infrage, falls Henning diese Entscheidung ausdrücklich revidiert.
- **Ein individueller Reminder-Zeitpunkt je Aufgabe** (mehrere Mitteilungs-Zeitpunkte statt des
  einen täglichen 9-Uhr-Sammel-Pushs, exakt zur `repeatRule.hour`-Zeit): in der Intake-Klärung
  explizit verworfen (siehe Risiko 1) — würde `DueReminders.plan` grundlegend umbauen, weit über
  den Scope dieses Tickets hinaus.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive unverändert grüner #102-Tests
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors), jeder Commit kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #127 (`Closes #127`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung bewegt sich innerhalb ADR-7 (Wiederholung ohne Serie: `RepeatRule`
  auf der Task, kein Template/keine Instanz — `firstDueDate` ist eine weitere reine Funktion auf
  demselben Struct, kein neuer Baustein). ADR-3 (Rohtext unveränderlich, abgeleitete Felder mit
  Herkunft und Konfidenz) wird hier — im Unterschied zu #102 — bewusst **angewendet**: `dueDate`
  bleibt ein Enrichment-Feld mit eigener `RevisedField`-Historie, nur der Auslöser dieser einen
  Schreiboperation ist eine manuelle User-Handlung im Editor, konsistent mit der bestehenden
  Behandlung von `setDue` für jede andere Freihandänderung des Datums. Keine neue ADR-Nummer nötig,
  reine Anwendung bestehender Festlegungen auf einen neuen Auslöser.

## Changelog

- 2026-09-25: Spec aus der Analyse-Zusammenfassung (Phase 2, #127, Folgeticket aus #102) erstellt.
