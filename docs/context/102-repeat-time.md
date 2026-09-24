# Context: #102 — Freistehende Uhrzeit ohne Datum geht verloren

## Request Summary

„Jeden Tag um 7 Uhr die Tabletten nehmen" liefert eine erkannte Uhrzeit, die heute nirgends
gespeichert wird, weil `DateExpressionParser.isRepetition` bewusst verhindert, dass eine
Wiederholung ein Fälligkeitsdatum bekommt, und `TaskItem.dueHasTime` nur ein Flag neben `dueDate`
ist. PO-Entscheidung aus der Intake-Klärung (2026-09-24): **kein** automatisches Anlegen einer
`RepeatRule` aus dem Text in diesem Ticket — nur die Uhrzeit selbst bekommt einen Platz, sobald
eine `RepeatRule` da ist.

## Related Files

| File | Relevance |
|------|-----------|
| `Shared/Models/RepeatRule.swift` | Ziel-Struct. Reines `Codable, Hashable, Sendable`, kein `@Model`. Felder: `frequency` (nicht optional), `interval`, `weekdays`, `basis`. Kein Zeit-Feld. `nextDueDate(previousDue:completedOn:calendar:)` rechnet nur auf Tagesebene. |
| `Shared/Enrichment/DueDateRule.swift` | Wo die Uhrzeit aktuell verworfen wird. `match(in:reference:calendar:)` bricht in Zeile 26-27 mit `guard let day = parser.resolve(...)` ab, **bevor** `TimeExpressionParser().time(in:)` (Zeile 31) überhaupt aufgerufen wird, wenn `isRepetition` zuschlägt. Kommentar Zeile 21-23 benennt das Problem bereits explizit. |
| `Shared/Services/DateExpressionParser.swift:146-154` | `isRepetition(before:in:)` und die Wortliste `repetitions` (`jeden, jede, jeder, jedes, jedem, every, werktags, taglich, wochentlich, monatlich, jahrlich, daily, weekly, monthly`). Wird als Filter in `expression(in:)` (Zeile 93) angewendet. |
| `Shared/Services/TimeExpressionParser.swift` | Findet die früheste Uhrzeit im Text, unabhängig von `isRepetition` — kennt den Wiederholungs-Kontext gar nicht. Über den Vollkorpus zu 100 % gemessen (#92). |
| `Shared/Enrichment/EnrichmentCoordinator.swift:84-107` | `applyRules`/`applyDueDateRule`: automatischer Regelschritt, läuft **einmal pro Task**, für Tasks mit `processedAt == nil` (frisch erfasst oder Nachhol-Lauf). Setzt `dueDate`, `dueHasTime`, `dueSourceRaw`, `dueConfidence` + Revision. **Prüft nicht auf `task.repeatRule`.** |
| `LooseEnds/Views/FieldEditorView.swift:161-232` | `repeatControl`/`weekdayRow`/`applyRepeat`. Die **einzige** Stelle, an der `repeatRule` heute gesetzt wird — ausschließlich manuell über Picker/Stepper. Kein automatisches Anlegen aus Rohtext existiert irgendwo im Code. |
| `LooseEnds/Views/FieldFormatting.swift:45-70` | `repeatDescription`/`intervalDescription` — Textdarstellung „Weekly · Mon, Sat" bzw. „Every 2 months · after completion". Kein Uhrzeit-Anteil. |
| `Shared/Notifications/DueReminders.swift:26-39` | `plan(for:hour:now:calendar:)`: `guard ... let due = task.dueDate else { return nil }` — Tasks **ohne** `dueDate` (reine Wiederholung ohne je gesetztes Fälligkeitsdatum) bekommen aktuell **keinen** Reminder, unabhängig von `repeatRule`. Feste `defaultHour = 9`, Minute explizit auf `0`. |
| `Shared/Services/FieldCodec.swift:81-91` | `encode(_ rule: RepeatRule)`/`decodeRepeat` — JSON-Kodierung für Revision-/Editor-Pipeline. Generisch über `RepeatRule`, ändert sich automatisch mit, wenn das Struct ein Feld bekommt. |
| `Shared/Models/TaskItem.swift:28-29` | `var repeatRule: RepeatRule?` — direkt als optionales Property, SwiftData codiert `Codable`-Structs nativ. |

## Existing Patterns

- **Regeln vor Modell (#95):** `DueDateRule` ist der Referenz-Baustein für „Rohtext → Guess-Tripel
  (Wert, Konfidenz 1.0, lokalisierter Grund)". Ein neuer Baustein für die Wiederholungs-Uhrzeit
  sollte demselben Muster folgen: reines `Foundation`, kein `#if canImport(FoundationModels)`,
  damit `Shared/` weiter in Watch/Widgets/Share kompiliert.
- **Revision-Schreibweg:** `applyDueDateRule`/`applyImportanceRule`/`applyUrgencyRule` in
  `EnrichmentCoordinator` folgen alle demselben Muster: `guard <Feld leer>, let guess = ... else
  { return }`, dann `Revision` anlegen, Feld setzen, `FieldSource.ai`. Ein neuer Schritt für die
  Wiederholungs-Uhrzeit würde vermutlich in diese Reihe passen — **mit der Einschränkung**, dass er
  laut PO-Entscheidung nur greifen soll, wenn `task.repeatRule` bereits existiert.
- **Reason-Text lokalisiert, sprachunabhängig von der Notiz** (`DueDateRule.reason(for:)`) — Vorbild
  für einen eigenen Grundsatz, falls die Uhrzeit ebenfalls einen Revision-Grund bekommt.

## Dependencies

- **Upstream:** `DateExpressionParser.isRepetition` (unverändert bleiben soll: „Jeden Tag um 7 Uhr"
  darf weiterhin kein Fälligkeitsdatum erzeugen — Teil 2 der DoD), `TimeExpressionParser.time(in:)`
  (liefert Stunde/Minute, kennt keinen Kontext).
- **Downstream:** `FieldEditorView.repeatControl` (müsste die Uhrzeit anzeigen/editierbar machen,
  falls UI-Teil des Scopes), `FieldFormatting.repeatDescription` (Textdarstellung),
  `FieldCodec.encode(_ rule:)`/`decodeRepeat` (automatisch mit, sobald `RepeatRule` ein Feld
  bekommt — Revision-Diffs zeigen den JSON-String aber roh an, das ändert sich nicht von selbst).
  `DueReminders.plan` bleibt laut aktuellem Scope unangetastet (siehe Risiken).

## Existing Specs

- `docs/specs/enrichment/feat-95-parser-in-app.md` — Ursprungsspec, in der #102 explizit unter
  „Nicht-Scope" benannt wird: *„Freistehende Uhrzeit für Wiederholungsregeln (‚jeden Tag um 7 Uhr'):
  `TimeExpressionParser` erkennt die Uhrzeit, aber `TaskItem.dueHasTime` ist ein Flag neben
  `dueDate`, kein eigener Zeit-Slot. Gehört in ein Folge-Issue zur Wiederholungsregel, sobald die
  dafür nötige Modellierung ansteht."* Abschnitt „Alternativen" derselben Spec verwirft explizit
  „Freistehende Uhrzeit ohne Datum in ein eigenes Feld schreiben" mit derselben Begründung — das ist
  jetzt genau das hier anstehende Folge-Issue.
- Kein bestehender Spec-Eintrag zu `RepeatRule` selbst.

## Risks & Considerations

1. **Auslöse-Zeitpunkt ungeklärt.** `applyRules` im `EnrichmentCoordinator` läuft genau einmal pro
   Task, direkt nach Erfassung (`processedAt == nil`). `repeatRule` wird aber ausschließlich manuell
   im `FieldEditorView` gesetzt — typischerweise **nachdem** die Task längst verarbeitet ist
   (`processedAt` bereits gesetzt). D. h. der Fall „Task hat beim automatischen Regeldurchlauf schon
   eine `repeatRule`" tritt über den heutigen Ablauf praktisch nie ein. Die Analyse-Phase muss klären,
   *wo* die Uhrzeit tatsächlich einfließt — Kandidaten: (a) beim manuellen Setzen/Ändern der
   `repeatRule` im Editor wird der Rohtext erneut auf eine Uhrzeit geprüft und vorbefüllt, (b) ein
   neuer, vom `processedAt`-Marker unabhängiger Regelschritt lässt sich erneut anstoßen, sobald eine
   `repeatRule` gesetzt wird, (c) etwas Drittes. Das ist die zentrale offene Frage dieses Tickets.
2. **`DueReminders` bleibt außen vor.** Reine Wiederholungen ohne `dueDate` lösen heute keinen
   Reminder aus, unabhängig von `repeatRule`. Die DoD von #102 nennt Reminder nicht — falls die
   Uhrzeit ohne Wirkung auf Erinnerungen bliebe, wäre das für den Nutzer wenig greifbar. Vom PO als
   „nicht in diesem Ticket" zu bestätigen oder als eigenes Folge-Issue zu benennen.
3. **Gepinnter Test.** `LooseEndsTests/DueDateRuleTests.swift:62-72`,
   `timeWithoutDateYieldsNothing` (AC-6 aus #95), testet exakt das heutige „kein Ergebnis"-Verhalten
   für „Jeden Tag um 7 Uhr …". Bleibt laut DoD-Punkt 2 von #102 unverändert grün — der neue Weg für
   die Uhrzeit darf `DueDateRule.match` selbst nicht verändern, sondern muss daneben liegen.
4. **UI-Umfang offen.** Ob `FieldEditorView`/`FieldFormatting` in diesem Ticket überhaupt angefasst
   werden (Uhrzeit anzeigen/editierbar machen) oder ob das reine Datenmodell reicht und die
   Anzeige ein Folge-Issue ist, klärt die Analyse-Phase.

## Referenzierte Tests (Vorlage für neue Fälle)

- `LooseEndsTests/DueDateRuleTests.swift` — insbesondere `timeWithoutDateYieldsNothing` (Zeile 62-72).
- `LooseEndsTests/RepeatEditTests.swift` — UI-nahe Tests für `RepeatRule`-Bearbeitung im
  `FieldEditorView`.
- `LooseEndsTests/TimeExpressionParserTests.swift`, `LooseEndsTests/DateExpressionParserTests.swift`.
- `LooseEndsTests/DueRemindersTests.swift` — falls Reminder-Logik doch angefasst wird.
- `LooseEndsTests/TaskActionsTests.swift` — testet `RepeatRule.nextDueDate` im Zusammenspiel mit
  `TaskActions.complete`; relevant, falls die Uhrzeit beim Fortschreiben übernommen werden soll.

## Analysis

### Type
Feature (Folgeticket aus #95, explizit als Nicht-Scope benannt — keine defekte Funktion, sondern
fehlende Modellierung).

### Zentrale Frage geklärt: Auslöse-Zeitpunkt = Kandidat (a)

Per `grep -rn "repeatRule"` über `Shared/` und `LooseEnds/` (ohne Tests) verifiziert: `task.repeatRule`
wird im gesamten Produktcode **ausschließlich** in `FieldEditorView.repeatControl` → `applyRepeat`
(`LooseEnds/Views/FieldEditorView.swift:164-232`) geschrieben. `EnrichmentCoordinator.applyRules`
fasst `repeatRule` nirgends an, es gibt keinen dritten Schreibpfad. Kandidat (a) — Prefill beim
manuellen Neuanlegen der Regel im Editor — ist damit nicht nur pragmatisch, sondern der einzig
belastbare Weg. Kandidat (b) (ein vom `EnrichmentCoordinator` unabhängig angestoßener Regelschritt)
würde am selben Trigger-Punkt enden, nur über eine für Batch-Verarbeitung gebaute
Coordinator-Abstraktion umgeleitet — zusätzliche Kopplung UI→Enrichment-Layer ohne Erkenntnisgewinn.

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|--------------|
| `Shared/Models/RepeatRule.swift` | MODIFY | Zwei neue optionale Felder `hour: Int?`, `minute: Int?` (kein `DateComponents` — folgt dem Muster von `TimeExpressionParser.time(in:)`, das bereits `(hour: Int, minute: Int)` liefert). Neuer reiner Helfer `static func timeGuess(from rawText: String) -> (hour: Int, minute: Int)?` als dünner Pass-Through auf `TimeExpressionParser`. |
| `LooseEnds/Views/FieldEditorView.swift` | MODIFY | `repeatControl`-Picker-Closure: beim Neuanlegen einer Regel (`rule == nil → next`) `RepeatRule.timeGuess(from: task.rawText)` aufrufen und `hour`/`minute` vorbefüllen. Greift nur beim Neuanlegen, nie bei nachträglicher Änderung einer bestehenden Regel. |
| `LooseEndsTests/RepeatEditTests.swift` (oder neue `RepeatRuleTests.swift`) | CREATE/MODIFY | Unit-Tests für `timeGuess` (TDD RED zuerst) + Codec-Round-Trip mit gesetzter Zeit. |

`FieldCodec.encode(_ rule:)`/`decodeRepeat` brauchen **keine** Änderung — generisch über
`Codable`, synthetisiertes `Encodable` nutzt bei optionalen Properties `encodeIfPresent`.
`LooseEndsTests/DueDateRuleTests.swift` bleibt unverändert (Regressions-Pin, siehe Risiken).

### Scope Assessment
- Files: 3 (davon 1 Test-Datei)
- Estimated LoC: ~60–70 gesamt (RepeatRule ~15, FieldEditorView ~12, Tests ~30–40)
- Risk Level: NIEDRIG — liegt deutlich innerhalb des Projekt-Limits (max. 4–5 Dateien, ±250 LoC),
  kein Split nötig

### Technical Approach
Empfehlung: `RepeatRule` bekommt `hour`/`minute` als optionale `Int`. Ein neuer Helfer
`RepeatRule.timeGuess(from:)` liest die Uhrzeit über den bereits 100 % gemessenen
`TimeExpressionParser` (kein neues Erkennungsrisiko). Geschrieben wird ausschließlich in
`FieldEditorView.repeatControl`, im Moment des Neuanlegens einer Regel — der einzige Ort im
Produktcode, an dem `repeatRule` je entsteht. `DateExpressionParser.isRepetition` und
`DueDateRule.match` bleiben komplett unangetastet; der neue Pfad liegt strukturell daneben, wodurch
DoD-Punkt 2 ("kein Fälligkeitsdatum") automatisch erhalten bleibt.

**Verworfene Alternative:** Ein vom `processedAt`-Marker unabhängiger, erneut anstoßbarer
Regelschritt im `EnrichmentCoordinator`, der auf `repeatRule`-Änderungen reagiert. Verworfen, weil
`EnrichmentCoordinator.processPending` für Batch-Durchläufe über unverarbeitete Tasks gebaut ist
und heute nie von einer offenen View aus aufgerufen wird — der Umweg bräuchte einen neuen
Beobachtungsmechanismus (View→Coordinator-Kopplung), der im Projekt nirgends existiert, und würde
am selben Trigger-Punkt wie (a) enden. Mehr Fläche für Fehler, kein Zusatznutzen.

### UI-Umfang (Risiko 4 geklärt)
`FieldEditorView` muss minimal angefasst werden (unvermeidbar, da einziger Schreibort), aber nur die
Prefill-Logik im bestehenden Picker-Closure (~12 LoC) — **kein** neuer Time-Picker, kein Toggle.
`FieldFormatting.repeatDescription`/`intervalDescription` bleiben in diesem Ticket unangetastet;
Anzeige/Editierbarkeit der Uhrzeit ist ein eigenes Folgeticket, sobald geklärt ist, ob/wie die Zeit
auch in `nextDueDate`/Reminder wirken soll.

### DueReminders (Risiko 2 geklärt)
Bewusst unangetastet lassen. `DueReminders.plan` bricht bei Tasks ohne `dueDate` ohnehin ab
(`guard ... let due = task.dueDate else { return nil }`) — reine Wiederholungen bekommen so oder so
keinen Reminder, unabhängig von `repeatRule.hour`. Die neue Zeit hat aktuell keine beobachtbare
Wirkung auf Reminder; das ist in Ordnung, weil die DoD Reminder nicht erwähnt, aber als eigenes
Folge-Issue zu benennen ("Reminder für reine Wiederholungen ohne Fälligkeitsdatum, unter Nutzung
von `repeatRule.hour`/`minute`").

### Gepinnter Test (Risiko 3 geklärt)
`timeWithoutDateYieldsNothing` bleibt grün, da `DueDateRule.match` nicht verändert wird — der neue
Code läuft über einen komplett anderen Typ und Aufrufpfad (View statt Enrichment-Regel).

### Dependencies
1. `RepeatRule` um `hour`/`minute` + `timeGuess(from:)` erweitern (keine Abhängigkeiten)
2. Unit-Tests für `timeGuess` (TDD RED zuerst)
3. `FieldEditorView.repeatControl` anpassen (hängt an 1)
4. `RepeatEditTests` um Codec-Round-Trip mit gesetzter Zeit ergänzen (hängt an 1)
5. Gepinnte Tests (`DueDateRuleTests`, `TaskActionsTests`, `DueRemindersTests`) unverändert grün
   mitlaufen lassen als Beleg der Nicht-Beeinflussung

### Open Questions
- [x] Auslöse-Zeitpunkt — geklärt: Kandidat (a)
- [x] UI-Umfang — geklärt: nur `FieldEditorView`-Prefill, keine neue Zeit-UI
- [x] DueReminders — geklärt: bewusst außen vor, Folge-Issue vormerken
- [ ] Feld-Naming `hour`/`minute` vs. anderer Name — technische Entscheidung, keine Rückfrage nötig
