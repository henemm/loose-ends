---
entity_id: rule-102-repeat-time
type: feature
created: 2026-09-24
updated: 2026-09-24
status: draft
workflow: 102-repeat-time
---

# Spec: #102 — Freistehende Uhrzeit für Wiederholungsregeln

## Approval

- [ ] Approved

## Purpose

„Jeden Tag um 7 Uhr die Tabletten nehmen" liefert eine erkannte Uhrzeit (7:00), die heute nirgends
gespeichert wird: `DateExpressionParser.isRepetition` verhindert absichtlich, dass „jeden" ein
Fälligkeitsdatum erzeugt (das bleibt so — kein automatisches Datum aus Wiederholungstext, siehe
DoD), und `TimeExpressionParser().time(in:)` wird dadurch in `DueDateRule.match` nie erreicht. Die
Uhrzeit selbst hat aktuell keinen Platz im Datenmodell. PO-Entscheidung aus der Intake-Klärung
(2026-09-24): **kein** automatisches Anlegen einer `RepeatRule` aus dem Rohtext in diesem Ticket —
nur wenn der User bereits manuell eine `RepeatRule` anlegt, soll sie beim Anlegen mit der im Rohtext
erkannten Uhrzeit vorbefüllt werden. Diese Uhrzeit ist damit **kein Enrichment-Feld**: Sie hat keine
eigene `FieldSource`/`Revision`, weil `repeatRule` selbst bereits ein rein manuell gesetztes Feld ist
(anders als `dueDate`, `importance`, `urgency` in #95/#117, die von der automatischen
Enrichment-Pipeline geschrieben werden). Sie ist ein reiner UI-Prefill-Wert im Editor.

## Source

- **Datei:** `Shared/Models/RepeatRule.swift`
- **Bezeichner:** `struct RepeatRule`, `static func timeGuess(from:)` (neu)
- **Datei:** `LooseEnds/Views/FieldEditorView.swift`
- **Bezeichner:** `private var repeatControl` (Picker-Closure, Zeile 165-173)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `Shared/Services/TimeExpressionParser.swift` (`time(in:)`) | Vorbild/Wiederverwendung | Liefert `(hour: Int, minute: Int)?`, über den Vollkorpus zu 100 % gemessen (#92). `timeGuess` ist ein dünner Pass-Through darauf, kein neues Erkennungsrisiko. |
| `Shared/Enrichment/DueDateRule.swift` | Abgrenzung | Bleibt unangetastet — Kommentar Zeile 21-23 benennt das Problem bereits, aber die Lösung liegt strukturell daneben (anderer Typ, anderer Aufrufpfad), nicht in dieser Datei. |
| `Shared/Services/DateExpressionParser.swift` (`isRepetition`) | Abgrenzung | Bleibt unangetastet — verhindert weiterhin, dass Wiederholungstext ein Fälligkeitsdatum erzeugt (Teil der DoD). |
| `Shared/Services/FieldCodec.swift` (`encode(_ rule:)`/`decodeRepeat`) | Downstream | Generisch über `Codable`; `JSONEncoder(.sortedKeys)`/`JSONDecoder` behandeln neue optionale Felder automatisch korrekt (`encodeIfPresent`, fehlend → `nil`). Keine Änderung nötig. |
| `LooseEnds/Views/FieldFormatting.swift` (`repeatDescription`/`intervalDescription`) | Downstream, unangetastet | Zeigt die Uhrzeit in diesem Ticket nicht an — reines Datenmodell + Prefill reicht für die DoD. |
| `Shared/Notifications/DueReminders.swift` (`plan`) | Downstream, unangetastet | Bricht bei Tasks ohne `dueDate` ohnehin ab, unabhängig von `repeatRule.hour`. Kein Teil dieses Tickets, siehe Alternativen/Folge-Issue. |
| `docs/specs/enrichment/feat-95-parser-in-app.md` | Ursprungsspec | Benennt #102 explizit als Nicht-Scope und verwirft dort dieselbe Idee („eigenes Feld für freistehende Uhrzeit") mangels Modellierung — dieses Ticket liefert die Modellierung nach. |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Models/RepeatRule.swift` | MODIFY | Zwei neue optionale Felder `hour: Int?`, `minute: Int?` (kein `DateComponents`, folgt dem `(hour: Int, minute: Int)`-Muster von `TimeExpressionParser.time(in:)`). Neuer reiner Helfer `static func timeGuess(from rawText: String) -> (hour: Int, minute: Int)?` als dünner Pass-Through auf `TimeExpressionParser().time(in:)`. |
| `LooseEnds/Views/FieldEditorView.swift` | MODIFY | `repeatControl`-Picker-Closure (Zeile 165-173): beim Neuanlegen einer Regel (`var next = rule ?? RepeatRule(frequency: frequency)`, Zeile 169, nur wenn `rule` vorher `nil` war) `RepeatRule.timeGuess(from: task.rawText)` aufrufen und `next.hour`/`next.minute` vorbefüllen. Greift nur beim Neuanlegen, nie bei nachträglicher Änderung einer bestehenden Regel (Frequenz, Intervall, Wochentage, Basis). |
| `LooseEndsTests/RepeatRuleTests.swift` | CREATE | Unit-Tests für `RepeatRule.timeGuess` (TDD RED zuerst): Treffer, kein Treffer, Codec-Round-Trip mit gesetzter Zeit. |
| `LooseEndsTests/RepeatEditTests.swift` | MODIFY | Neuer Testfall für den Prefill beim Neuanlegen im `FieldEditorView` sowie den Nicht-Prefill bei bestehender Regel. |

**Geschätzter Umfang:** 2 Produktionsdateien + 2 Testdateien, ca. 60–70 LoC insgesamt (RepeatRule
~15, FieldEditorView ~12, Tests ~30–40) — deutlich unter der 250-LoC-Grenze und innerhalb der
4–5-Dateien-Richtgröße aus CLAUDE.md. Kein Split nötig.

## Implementation Details

**`RepeatRule.timeGuess(from:)` ist ein reiner, kontextfreier Pass-Through**, keine eigene
Erkennungslogik:

```
static func timeGuess(from rawText: String) -> (hour: Int, minute: Int)? {
    TimeExpressionParser().time(in: rawText)
}
```

`hour`/`minute` werden als optionale `Int` direkt auf `RepeatRule` ergänzt, mit Default `nil`
(bestehende gespeicherte Regeln ohne die Felder dekodieren unverändert dank `Codable`s
`decodeIfPresent`-Verhalten für optionale Properties).

**Geschrieben wird ausschließlich in `FieldEditorView.repeatControl`, im Moment des Neuanlegens.**
Per `grep -rn "repeatRule"` über `Shared/` und `LooseEnds/` (ohne Tests) verifiziert: `task.repeatRule`
wird im gesamten Produktcode ausschließlich an dieser einen Stelle geschrieben. Die
Picker-Closure-Zeile `var next = rule ?? RepeatRule(frequency: frequency)` ist bereits heute der
einzige Ort, an dem eine neue `RepeatRule` entsteht (wenn `rule` vorher `nil` war). Direkt danach:

```
var next = rule ?? {
    var created = RepeatRule(frequency: frequency)
    if let guess = RepeatRule.timeGuess(from: task.rawText) {
        created.hour = guess.hour
        created.minute = guess.minute
    }
    return created
}()
```

Bei nachträglicher Änderung einer bestehenden Regel (`rule` war bereits gesetzt) läuft `timeGuess`
**nicht** erneut — `next = rule` übernimmt die vorhandene `hour`/`minute` unverändert, unabhängig
davon, ob der User danach Frequenz, Intervall, Wochentage oder Basis ändert. Das ist eine bewusste
Verhaltensentscheidung (AC-3): Der Rohtext wird nur einmal, beim Entstehen der Regel, befragt.

**`DateExpressionParser.isRepetition` und `DueDateRule.match` bleiben komplett unangetastet.** Der
neue Code läuft über einen anderen Typ (`RepeatRule` statt `DueDateRule`) und einen anderen
Aufrufpfad (View statt automatischer Enrichment-Regel) — strukturell getrennt, kein gemeinsamer
Codepfad, der brechen könnte.

**`FieldCodec.encode(_ rule:)`/`decodeRepeat` brauchen keine Änderung** — `JSONEncoder` mit
`.sortedKeys` serialisiert optionale Properties automatisch über `encodeIfPresent` (synthetisiertes
`Encodable`), `JSONDecoder` liest fehlende Schlüssel als `nil`. Ein Round-Trip-Test belegt das
(AC-4), statt es nur zu behaupten.

**Kein Enrichment-Feld, keine `Revision`, keine `FieldSource`.** Anders als `dueDate` (#95) oder
`importance`/`urgency` (#117) wird `hour`/`minute` nicht über `EnrichmentCoordinator`/
`EnrichmentWriter` geschrieben und trägt keine eigene Konfidenz. `repeatRule` selbst ist bereits ein
rein manuelles Feld (nur der User setzt es, nie die automatische Pipeline) — der Prefill ist ein
Komfort-Startwert im Editor, keine Veredelung im Sinne von ADR-3/ADR-4. Der User kann den
vorbefüllten Wert wie jeden anderen Editor-Wert überschreiben (auch wenn dieses Ticket noch kein
UI-Element dafür schafft, siehe Nicht-Scope).

## Test Plan

### Automated Tests (TDD RED)

**Neu**
- `LooseEndsTests/RepeatRuleTests.swift`: GIVEN „Jeden Tag um 7 Uhr die Tabletten nehmen" / WHEN
  `RepeatRule.timeGuess(from:)` / THEN `(hour: 7, minute: 0)` (AC-1).
- Dieselbe Datei: GIVEN „Wöchentlich den Müll rausbringen" (kein erkennbares Zeit-Signal) / WHEN
  `RepeatRule.timeGuess(from:)` / THEN `nil` (AC-1).
- Dieselbe Datei: GIVEN eine `RepeatRule` mit `hour: 7, minute: 30` / WHEN über
  `FieldCodec.encode(_ rule:)` kodiert und mit `FieldCodec.decodeRepeat` wieder dekodiert / THEN
  liefert das Ergebnis identische `hour`/`minute`-Werte (AC-4).
- Dieselbe Datei: GIVEN eine `RepeatRule` ohne gesetzte `hour`/`minute` / WHEN über
  `FieldCodec.encode`/`decodeRepeat` rundgelaufen / THEN bleiben beide Felder `nil` (AC-4,
  Rückwärtskompatibilität mit vor diesem Ticket gespeicherten Regeln).
- `LooseEndsTests/RepeatEditTests.swift`: GIVEN eine Aufgabe mit Rohtext „Jeden Tag um 7 Uhr die
  Tabletten nehmen" und noch ohne `repeatRule` / WHEN im `FieldEditorView` über den Frequenz-Picker
  „Daily" gewählt wird / THEN ist `task.repeatRule?.hour == 7` und
  `task.repeatRule?.minute == 0` (AC-2).
- Dieselbe Datei: GIVEN eine Aufgabe mit bereits bestehender `repeatRule` (`hour: 7, minute: 0`,
  `frequency: .daily`) / WHEN im `FieldEditorView` die Frequenz auf „Weekly" geändert wird / THEN
  bleiben `hour`/`minute` unverändert bei `7`/`0` — kein erneuter `timeGuess`-Aufruf (AC-3).

**Geändert**
- Keine bestehenden Testfälle werden inhaltlich geändert.

**Entfallend**
- Keine.

**Unverändert grün (Regressionsbeleg)**
- `LooseEndsTests/DueDateRuleTests.swift`, `timeWithoutDateYieldsNothing` (Zeile 62-72, gepinnter
  Test aus #95 AC-6): bleibt unverändert grün — `DueDateRule.match` wird von diesem Ticket nicht
  angefasst (AC-5).
- `LooseEndsTests/TaskActionsTests.swift`: `RepeatRule.nextDueDate` bleibt unverändert auf
  Tagesebene, kein neuer Fall nötig — explizit Nicht-Scope dieses Tickets (siehe unten).

Kein neuer UI-Test: Es entsteht keine neue View, kein neuer Time-Picker, kein Toggle. Das Projekt
schreibt UI-Tests erst nach dem Design-Freeze und nur als Smoke-Tests (CLAUDE.md); die beiden
`RepeatEditTests`-Fälle oben sind bereits die bestehende, view-nahe Teststrecke für `repeatControl`
und keine neue UI-Testkategorie.

## Acceptance Criteria

- **AC-1 `timeGuess` erkennt/verwirft kontextfrei:** Given ein Rohtext mit erkennbarer Uhrzeit
  (z. B. „Jeden Tag um 7 Uhr die Tabletten nehmen") / When `RepeatRule.timeGuess(from:)` ihn
  verarbeitet / Then liefert er `(hour, minute)`; given ein Rohtext ohne erkennbares Zeit-Signal /
  Then liefert er `nil`.
- **AC-2 Prefill nur beim Neuanlegen:** Given eine Aufgabe ohne `repeatRule` und mit einer im
  Rohtext erkennbaren Uhrzeit / When der User im `FieldEditorView` erstmals eine Frequenz wählt /
  Then trägt die neu entstandene `RepeatRule` die erkannte `hour`/`minute`.
- **AC-3 Kein erneuter Prefill bei bestehender Regel:** Given eine Aufgabe mit bereits bestehender
  `repeatRule` und gesetzter `hour`/`minute` / When der User Frequenz, Intervall, Wochentage oder
  Basis dieser Regel ändert / Then bleiben `hour`/`minute` unverändert — kein erneuter
  `timeGuess`-Aufruf.
- **AC-4 Codec-Round-Trip verlustfrei:** Given eine `RepeatRule` mit gesetzter `hour`/`minute` /
  When über `FieldCodec.encode(_ rule:)` kodiert und mit `FieldCodec.decodeRepeat` wieder
  dekodiert / Then sind beide Werte identisch erhalten; given eine `RepeatRule` ohne gesetzte
  `hour`/`minute` / Then bleiben beide nach dem Round-Trip `nil`.
- **AC-5 Kein automatisches Fälligkeitsdatum aus Wiederholungstext (Regression):** Given der
  gepinnte Test `DueDateRuleTests.timeWithoutDateYieldsNothing` / When `./scripts/sim.sh unit`
  läuft / Then bleibt er unverändert grün — `DateExpressionParser.isRepetition` und
  `DueDateRule.match` sind von diesem Ticket nicht verändert.

## Risiken

1. **`timeGuess` liefert eine irreführende Uhrzeit, wenn der Rohtext mehrere Zeitangaben enthält**
   (z. B. „Zwischen 7 und 9 Uhr anrufen, danach jeden Tag um 15 Uhr üben" — `time(in:)` liefert nur
   die früheste). Gegenmaßnahme: `TimeExpressionParser` ist bereits über den Vollkorpus zu 100 %
   gemessen (#92) und wird hier unverändert wiederverwendet — kein neues Erkennungsrisiko
   gegenüber dem Status quo, dasselbe Verhalten wie überall sonst, wo `time(in:)` bereits läuft.
2. **Der Prefill wird vom User übersehen, weil dieses Ticket kein sichtbares Uhrzeit-Feld im Editor
   schafft** — `hour`/`minute` sind gesetzt, aber nirgends angezeigt. Gegenmaßnahme: bewusst
   begrenzter Scope laut PO-Klärung; Anzeige/Editierbarkeit ist ein eigenes Folgeticket (siehe
   Alternativen), sobald geklärt ist, ob/wie die Zeit auch in `nextDueDate`/Reminder wirken soll.
3. **`DueReminders` bleibt wirkungslos gegenüber der neuen Uhrzeit** — reine Wiederholungen ohne
   `dueDate` bekommen weiterhin keinen Reminder. Gegenmaßnahme: bewusst außerhalb der DoD dieses
   Tickets (DoD nennt Reminder nicht); als Folge-Issue benannt, nicht in diesem PR angelegt.

## Alternativen

- **Automatisches Anlegen der `RepeatRule` direkt aus dem Rohtext** (ohne dass der User erst
  manuell „Daily" wählt): wurde in der Intake-Klärung vom PO (2026-09-24) explizit ausgeschlossen.
  Nur infrage, falls Henning diese Entscheidung ausdrücklich revidiert.
- **Ein vom `EnrichmentCoordinator`/`processedAt`-Marker unabhängiger Regelschritt**, der auf
  `repeatRule`-Änderungen reagiert (Kandidat (b) aus der Analyse): verworfen, weil
  `EnrichmentCoordinator.processPending` für Batch-Durchläufe über unverarbeitete Tasks gebaut ist
  und nie von einer offenen View aus aufgerufen wird. Der Umweg bräuchte einen neuen
  Beobachtungsmechanismus (View→Coordinator-Kopplung), der im Projekt nirgends existiert, und würde
  am selben Trigger-Punkt wie der gewählte Weg enden — mehr Fläche für Fehler, kein Zusatznutzen.
- **Uhrzeit sofort auch in `FieldFormatting.repeatDescription` anzeigen und editierbar machen**
  (neuer Time-Picker/Toggle im `FieldEditorView`): verworfen/verschoben als eigenes Folgeticket,
  weil unklar ist, ob/wie die Zeit auch in `nextDueDate`/`DueReminders` wirken soll (Risiko 2/3) —
  ohne diese Klärung wäre ein UI-Element vorschnell, das eine Wirkung suggeriert, die es noch nicht
  gibt.

**Folge-Issue (nicht Teil dieser Spec, nach Freigabe anzulegen):** „Reminder für reine
Wiederholungen ohne Fälligkeitsdatum, unter Nutzung von `repeatRule.hour`/`minute`" — analog zu
#118 in `docs/specs/enrichment/rule-117-importance-urgency.md`.

## Definition of Done

- [ ] AC-1 bis AC-5 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive unverändertem `timeWithoutDateYieldsNothing`
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors), jeder Commit kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #102 (`Closes #102`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün
- [ ] Folge-Issue „Reminder für reine Wiederholungen ohne Fälligkeitsdatum" benannt (nach
      Freigabe vom Hauptagenten als GitHub Issue angelegt, nicht Teil dieses PRs)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung bewegt sich innerhalb ADR-7 (Wiederholung ohne Serie: `RepeatRule` auf
  der Task, kein Template/keine Instanz — `hour`/`minute` sind zwei weitere Felder auf demselben
  Struct, kein neuer Baustein). ADR-3 (Rohtext unveränderlich, abgeleitete Felder mit Herkunft und
  Konfidenz) wird bewusst **nicht** angewendet: `hour`/`minute` sind kein Enrichment-Feld mit
  `FieldSource`/`Revision`, weil `repeatRule` selbst bereits ein rein manuell gesetztes Feld ist,
  nie von der automatischen Pipeline geschrieben wird (siehe Purpose). Diese Abgrenzung ist eine
  bewusste Scope-Entscheidung dieser Spec, keine neue Architektur, die eine eigene ADR-Nummer
  rechtfertigt.

## Changelog

- 2026-09-24: Spec aus der Analyse-Zusammenfassung (Phase 2, #102, Folgeticket aus #95) erstellt.
