# Context: feat-127-repeat-reminder (#127)

## Request Summary

Eine frisch angelegte reine Wiederholung ("jeden Tag um 7 Uhr die Tabletten nehmen") hat noch kein
`dueDate` und bekommt deshalb nie eine Erinnerung — `DueReminders.plan` bricht ohne `dueDate`
ohnehin ab. PO-Entscheidung (2026-09-24, Intake): beim Neuanlegen einer `RepeatRule` sofort ein
implizites erstes `dueDate` setzen, statt `DueReminders` um eine von `dueDate` losgelöste
Planungslogik zu erweitern. Das ist derselbe Schnittpunkt, den #102 bereits verändert hat.

## Related Files

| File | Relevance |
|------|-----------|
| `LooseEnds/Views/FieldEditorView.swift` | `repeatControl` (Picker-Closure, ~Zeile 165) legt eine neue `RepeatRule` an — hier soll beim Neuanlegen zusätzlich `task.dueDate` gesetzt werden. `applyRepeat`/`apply` (Zeile 227, 259) schreiben nur das Feld `field` (hier `.repeatRule`) über `RevisionService.set`; `dueDate` braucht einen eigenen, direkten `RevisionService.set(.dueDate, …)`-Aufruf, analog zu `setDue` (Zeile 234). |
| `Shared/Models/RepeatRule.swift` | `nextDueDate(previousDue:completedOn:calendar:)` (Zeile 19) berechnet bereits das nächste Datum aus einer Regel — mit `previousDue: nil` liefert sie den ersten Termin ab "jetzt". `hour`/`minute` (Zeile 15-16, aus #102) müssen auf das berechnete Datum angewendet werden, bevor es gespeichert wird. `timeGuess(from:)` (Zeile 48) bleibt unverändert. |
| `Shared/Notifications/DueReminders.swift` | `plan(for:hour:now:calendar:)` (Zeile 26) bricht bei `task.dueDate == nil` ab (Zeile 33) — **keine Änderung nötig**, sobald ein `dueDate` existiert, greift die bestehende Logik automatisch. Wichtig: `hour` ist hier ein einziger globaler Parameter (Default 9) für **alle** Aufgaben — die "Heute fällig"-Mitteilung ist ein täglicher Sammel-Push um 9 Uhr, kein Reminder zur individuellen `repeatRule.hour`/`.minute`. Das gilt es in der Analyse als Erwartungsmanagement festzuhalten: Die Aufgabe taucht ab ihrem Fälligkeitstag im 9-Uhr-Sammel-Push auf, nicht exakt um 7 Uhr. |
| `Shared/Services/TaskActions.swift` | `complete(_:now:calendar:)` (Zeile 13-19) ist das bestehende Vorbild für "aus einer Regel ein neues `dueDate` berechnen": `task.dueDate = rule.nextDueDate(previousDue: task.dueDate, completedOn: now, calendar: calendar)`. Bleibt unverändert — nach dem ersten Abhaken übernimmt weiterhin dieser Pfad, unabhängig davon, ob das erste `dueDate` implizit oder vom User gesetzt wurde. |
| `Shared/Services/RevisionService.set` | Schreibt eine `Revision` mit `author: .user` — passt, weil das Setzen im Editor eine manuelle Aktion ist (kein Enrichment-Feld, siehe #102-Spec-Präzedenzfall für `repeatRule`/`hour`/`minute`). |
| `Shared/Models/ViewRules.swift` | `.due` (Zeile 18-21) filtert auf `dueDate <= now + 7 Tage` — ein implizites `dueDate` aus einer täglichen/wöchentlichen Regel erscheint sofort oder bald in der "Fällig"-Ansicht; bei monatlichen/jährlichen Regeln typischerweise noch nicht (Termin liegt weiter in der Zukunft) — das ist beabsichtigtes, unverändertes Verhalten der bestehenden View-Filterung. `.repeating` (Zeile 31-33) zeigt ohnehin jede Aufgabe mit `repeatRule != nil`, unabhängig von `dueDate`. |
| `Shared/Services/CalendarSync.swift` | Prüft `task.dueHasTime` (Zeile 21) für Ganztag- vs. Uhrzeit-Termin. Wird `dueHasTime` beim impliziten Setzen korrekt aus `repeatRule.hour != nil` abgeleitet, bekommt die Aufgabe automatisch einen Kalendertermin zur richtigen Uhrzeit — kein zusätzlicher Code nötig, reiner Mitnahme-Effekt der bestehenden Kalender-Synchronisierung. |

## Existing Patterns

- **Einmaliger Prefill beim Neuanlegen (#102):** `RepeatRule.timeGuess` wird nur aufgerufen, wenn
  `rule` vorher `nil` war (`var next = rule ?? { … }()`), nie bei nachträglicher Änderung einer
  bestehenden Regel. Dasselbe Muster gilt für das neue `dueDate`: nur beim allerersten Anlegen der
  Regel, nicht bei jeder späteren Änderung von Frequenz/Intervall/Wochentagen — sonst würde ein
  bereits vom User gesetztes oder durch Abschließen fortgeschriebenes `dueDate` überschrieben.
- **Direkter `RevisionService.set` außerhalb von `field`:** `setDue` (Zeile 234) zeigt bereits, wie
  eine `FieldEditorView`-Instanz, deren `field` eigentlich `.repeatRule` ist, trotzdem gezielt
  `.dueDate` schreiben kann — derselbe Aufrufstil ist hier zu verwenden.
- **`nextDueDate` als reine, kontextfreie Funktion:** nimmt `previousDue: Date?` — mit `nil` als
  Anker fällt sie auf `completedOn` zurück (Zeile 21: `previousDue ?? completedOn`). Für den
  allerersten Termin ist `now` der sinnvolle `completedOn`-Wert.

## Dependencies

- **Upstream:** `RepeatRule.nextDueDate`, `RevisionService.set`, `Calendar.current` (Zeitzonen-/
  Kalenderrechnung wie überall sonst im Projekt).
- **Downstream:** `DueReminders.plan` (unverändert, profitiert automatisch), `ViewRules.tasks(for: .due)`
  (unverändert, filtert automatisch), `CalendarSync` (unverändert, synchronisiert automatisch).

## Existing Specs

- `docs/specs/enrichment/rule-102-repeat-time.md` — legt `hour`/`minute` auf `RepeatRule` an, nennt
  dieses Ticket explizit als Folge-Issue (Abschnitt "Alternativen", letzter Absatz) und hält fest:
  `hour`/`minute` sind **kein** Enrichment-Feld (keine eigene `FieldSource`/`Revision`), weil
  `repeatRule` selbst rein manuell gesetzt wird. Dieselbe Einordnung gilt für das aus ihnen
  abgeleitete `dueDate` an dieser Stelle nicht automatisch — `dueDate` bleibt weiterhin ein
  Enrichment-Feld mit eigener `RevisedField`-Historie; nur der *Auslöser* (die Editor-Aktion) ist
  hier eine manuelle User-Handlung, ebenso wie `setDue` (Freihandänderung des Datums) bereits heute
  eine manuelle `.user`-Revision auf `.dueDate` schreibt.
- `docs/specs/enrichment/feat-95-parser-in-app.md` — `DueDateRule` bleibt komplett unangetastet
  (anderer Aufrufpfad, siehe #102-Spec).

## Risks & Considerations

1. **Erwartungslücke bei der Uhrzeit:** Die tägliche "Fällig"-Mitteilung feuert für alle Aufgaben
   einheitlich um 9 Uhr (`DueReminders.defaultHour`) — nicht exakt zur in `repeatRule.hour` erkannten
   Zeit. Muss in der Spec klar benannt werden, damit die Acceptance Criteria nicht fälschlich "Reminder
   um 7 Uhr" verlangen, sondern "Aufgabe erscheint im 9-Uhr-Sammel-Push, sobald ihr Fälligkeitsdatum
   erreicht ist".
2. **Kein erneuter Prefill bei bestehender Regel:** Muss exakt wie bei #102 AC-3 nur beim Neuanlegen
   greifen (`rule == nil` vorher), sonst überschreibt eine spätere Frequenzänderung ein bereits vom
   User gesetztes oder durch Completion fortgeschriebenes `dueDate`.
3. **Wochentag-lose wöchentliche Regel:** `nextDueDate` fällt ohne `weekdays` auf "+7×interval Tage"
   zurück (Zeile 28) — für den allerersten Termin ohne Anker plausibel, aber nicht "der nächste
   gewählte Wochentag", weil beim Anlegen oft noch kein Wochentag gewählt ist. Bestehendes,
   unverändertes Verhalten von `nextDueDate` — kein neuer Sonderfall nötig.
4. **`dueHasTime`-Kopplung:** Nur setzen, wenn `repeatRule.hour != nil` — sonst (kein erkanntes
   Zeit-Signal im Rohtext) das bestehende Muster "Datum ohne Zeit → `startOfDay`" aus `setDue`
   übernehmen.

## Nicht-Scope

- Keine Änderung an `DueReminders.plan`, `DueDateRule`, `DateExpressionParser.isRepetition` — alle
  drei bleiben laut #102-Spec und laut PO-Entscheidung (Intake #127) unangetastet.
- Kein neuer, individueller Reminder-Zeitpunkt je Aufgabe — das wäre eine eigene, deutlich größere
  Funktion (mehrere Mitteilungs-Zeitpunkte statt des einen täglichen 9-Uhr-Sammel-Push) und war die
  in der Intake-Klärung explizit verworfene Alternative.

## Analysis

### Type
Feature (ausgelöst durch einen gemeldeten Fehlerfall, aber laut Intake-Entscheidung als gezielte
Erweiterung umgesetzt — kein Eingriff in `DueReminders`).

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/RepeatRule.swift` | MODIFY | Neue reine, testbare Funktion `firstDueDate(now:calendar:)` — kombiniert `nextDueDate(previousDue: nil, completedOn: now)` mit `hour`/`minute`. |
| `LooseEnds/Views/FieldEditorView.swift` | MODIFY | `applyRepeat` (Zeile 227) setzt bei `isNewRule && task.dueDate == nil` das `dueDate` über das bestehende `setDue` (Zeile 234). |
| `LooseEndsTests/RepeatRuleTests.swift` | MODIFY | Unit-Tests für `firstDueDate` (mit/ohne erkannte Uhrzeit, wöchentlich ohne Wochentage). |
| `LooseEndsTests/RepeatEditTests.swift` | MODIFY | Integrationstest für den Editor-Ablauf, insbesondere die Guard-Bedingung (kein Überschreiben eines bereits gesetzten `dueDate`, kein erneuter Prefill bei bestehender Regel). |

### Scope Assessment
- Files: 4 (innerhalb des 4-5-Dateien-Limits)
- Estimated LoC: ca. +80 bis +110 (Modell-Funktion ~8, View-Anbindung ~10, Tests ~60-90)
- Risk Level: **LOW** — additive, reine Funktion, ein einziger verifizierter Schreibpfad, keine Änderung an `DueReminders`/`ViewRules`/`CalendarSync`.

### Technical Approach
Reine Modell-Funktion `RepeatRule.firstDueDate(now:calendar:)`, aufgerufen aus `FieldEditorView.applyRepeat`
— nicht aus der Picker-Closure, weil `applyRepeat` der einzige Ort ist, der alten und neuen Regel-Zustand
kennt und von allen vier Editor-Controls aufgerufen wird. Verifiziert: `applyRepeat`/`apply` ist der einzige
produktive Schreibpfad für `repeatRule` im gesamten Projekt (einziger Instanziierungsort
`TaskDetailView.swift:130`, kein AI-Enrichment-Pfad dafür) — kein Risiko, einen zweiten Aufrufer zu übersehen.

Schreibguard: **`isNewRule && task.dueDate == nil`** — nicht nur "Regel ist neu", sondern zusätzlich "noch
kein `dueDate` gesetzt". Ohne den zweiten Teil würde ein bereits vom User manuell gesetztes Datum
überschrieben, wenn er danach eine Wiederholung hinzufügt (Erweiterung von Risiko 2 aus dem bisherigen
Kontext).

Geschrieben wird über das bestehende `setDue` (RevisionService, `.user`-Revision, korrektes `dueHasTime`),
**nicht** über den direkten Zuweisungsstil aus `TaskActions.complete`. Letzterer wäre hier falsch: `dueDate`
bleibt laut #102-Spec ein Enrichment-Feld mit eigener `RevisedField`-Historie, nur der Auslöser ist manuell.

### Dependencies & Reihenfolge (TDD RED zuerst)
1. Unit-Tests `RepeatRule.firstDueDate` (RED)
2. Modell-Funktion implementieren (GREEN)
3. Integrationstest für den Editor-Guard in `RepeatEditTests.swift` (RED)
4. `FieldEditorView.applyRepeat` anpassen (GREEN)
5. Simulator-Verifikation (End-to-End, `DueReminders`/`CalendarSync` bleiben unverändert)

Upstream: `RepeatRule.nextDueDate`, `RevisionService.set`, `Calendar.current`.
Downstream (unverändert, profitieren automatisch): `DueReminders.plan`, `ViewRules.tasks(for: .due)`, `CalendarSync`.

### Weitere Risiken (Ergänzung zur strategischen Prüfung)
5. **Kein "heute", nur "+1 Periode":** `nextDueDate` springt bei täglichen Regeln immer auf morgen, auch
   wenn die erkannte Uhrzeit heute noch bevorsteht (Regel "jeden Tag um 19 Uhr" morgens angelegt → erstes
   `dueDate` liegt auf morgen 19 Uhr, nicht heute). Bestehendes, unverändertes Verhalten von `nextDueDate`
   — muss aber explizit in die Acceptance Criteria, sonst wirkt es später wie ein neuer Bug.
6. **Bestandsdaten bleiben unversorgt:** Tasks mit `repeatRule`, aber ohne `dueDate`, die schon vor diesem
   Fix angelegt wurden (exakt der im Issue geschilderte Fall), bekommen den Fix nicht rückwirkend — nur ein
   erneutes Anfassen der Regel löst ihn aus. Muss als Nicht-Scope benannt werden, sonst Erwartungslücke
   nach dem Deploy ("warum bekomme ich für meine bestehende Tabletten-Aufgabe immer noch keine Erinnerung?").
7. **Zwei `save()`-Aufrufe statt einem:** `apply()` speichert bereits, `setDue` speichert erneut — funktional
   unproblematisch (kein Korrektheitsrisiko), aber zwei CloudKit-Push-Zyklen für eine logische Aktion. Keine
   Pflicht zur Behebung in diesem Scope.

### Alternative
Statt der View-Layer-Lösung: ein `didSet`/Setter-Wrapper direkt auf `TaskItem.repeatRule`, der bei jedem
Übergang nil→non-nil automatisch ein `dueDate` primt — robuster gegen einen künftigen zweiten Schreibpfad
(z.B. AI-Enrichment). Das würde jedoch die Festlegung aus `docs/specs/enrichment/rule-102-repeat-time.md`
kippen, dass `repeatRule` rein manuell gesetzt wird, und die Grenze zwischen Datenhaltung und
Editor-Geschäftslogik auflösen (Bruch mit dem Revision-Muster: Feld-Schreiblogik mit Nutzer-Intent gehört
in den Service-/View-Layer, nicht ins Modell). Da aktuell nachweislich nur ein einziger Schreibpfad
existiert, ist der Zusatzaufwand nicht gerechtfertigt — Empfehlung bleibt der View-Layer-Ansatz.

### Open Questions
- [ ] Keine offenen PO-Fragen — Ansatz ist technisch eindeutig, Risiken sind bekannt und im Scope
      abgedeckt (Risiko 6 als bewusster Nicht-Scope, kein Rückfrage-Bedarf).
