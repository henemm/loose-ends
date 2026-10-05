# Context: feature-25-siri-reminders-schema

## Request Summary
Issue #25: Siri soll Aufgaben über Apples App-Schema der Reminders-Domäne erfassen (ADR-9), nicht nur
über die eigene Phrase „Add to Loose Ends". Das Ticket nennt `TaskEntity` (konform zu `reminders.reminder`)
und die Intents `createReminder`, `updateReminder`, `deleteReminders` und `createList`.

## Recherche (2026-10-05)
Quellen: Apple-Doku als JSON (`developer.apple.com/tutorials/data/documentation/appintents/...`),
[WWDC26 Session 240 „Build intelligent Siri experiences with App Schemas"](https://developer.apple.com/videos/play/wwdc2026/240/),
[home-assistant/iOS PR #5660](https://github.com/home-assistant/iOS/pull/5660),
[Mindwtr #915](https://github.com/dongdongbh/Mindwtr/issues/915).

- **Domäne `.reminders`, alles ab iOS/iPadOS/macOS/visionOS 27.0, kein watchOS.**
  - Aktionen: `createReminder`, `updateReminder`, `deleteReminders`, `createList`, `createSection`.
  - Entities: `reminder`, `list`, `section`, `group`, `locationTrigger`.
  - Enums: `listType`, `locationTriggerEvent`.
- **`createReminder`** wird als `@AppIntent(schema: .reminders.createReminder)` deklariert.
  - Parameter: `title: String`, `list: ListEntity?`, `note: AttributedString?`, `isFlagged: Bool?`,
    `images: [IntentFile]`, `tags: Set<String>`, `urls: [URL]`, `dueDate: DateComponents?`,
    `recurrence: Calendar.RecurrenceRule?`, `locationTrigger: …?` und `section: …?`.
  - `perform()` muss `ReturnsValue<ReminderEntity>` liefern. Damit braucht schon die Minimalversion
    die Reminder-Entity.
- **`reminder`-Entity** wird als `@AppEntity(schema: .reminders.reminder)` deklariert.
  - Felder: `id`, `title`, `note`, `tags`, `urls`, `dueDate: DateComponents?`, `recurrence`,
    `isCompleted: Bool`, `isFlagged`, `creationDate`, `completionDate`, `locationTrigger` sowie
    **`list: ListEntity` (Pflicht, nicht optional)**.
  - Dazu kommt eine `EntityQuery` mit `entities(for:)`.
  - Folge: Auch die Minimalversion braucht eine **List-Entity** (`name`, `type: ListType`, Query).
- **`deleteReminders`** wird als `DeleteIntent` mit `entities: [ReminderEntity]` deklariert.
- Lokales Xcode 27.0 (27A266a, Swift 6.4): Die iOS-27-SDK enthält die Domäne
  (`AppIntents.swiftinterface`, `RemindersIntent`, `RemindersEntity`, `RemindersEnum`).
- Systemverhalten laut WWDC26: Apps mit diesem Schema erscheinen in Siri und Kurzbefehlen.
  Mehrere Anbieter zeigt das System als Ergebnis-Reiter, die Reihenfolge bestimmt das System.

## Related Files
| Datei | Relevanz |
|------|-----------|
| `Shared/Intents/CaptureTextIntent.swift` | Einzige Intent-Datei: `CaptureTextIntent`, `OpenCaptureIntent`, `LooseEndsShortcuts`. Die neuen Typen gehören daneben. |
| `Shared/Services/CaptureService.swift` | Einziger Schreibweg für neue Aufgaben (`save(_:via:sourceURL:in:)`). Setzt `TitleRule`-Titel (#202). Jeder Schema-Intent muss hierüber gehen. |
| `Shared/Services/TaskActions.swift` | `complete`, `park`, `restore`, `activate`, `move`. Ziel für `updateReminder` (isCompleted) und für ein „Löschen", das nicht löscht. |
| `Shared/Services/FieldCodec.swift`, `RevisionService.swift` | Jede Feldänderung als `Revision` mit Autor. Gilt für `updateReminder`. |
| `Shared/Models/TaskItem.swift` | `id: UUID` (stabil, laut Datenmodell „auch für App Intents"), `rawText` (unveränderlich), `title`, `dueDate` und `dueHasTime`, `project`, `status`, `completedAt`, `capturedAt`, `repeatRule`. |
| `Shared/Models/Project.swift` | „Projects are lists" (ADR-8). Kandidat für die List-Entity. Kein Typfeld, keine Eindeutigkeitsprüfung (#157 deckt nur Kontexte ab). |
| `Shared/Models/Enums.swift` | `CaptureChannel.siri` existiert schon. |
| `Shared/Persistence/ModelContainerFactory.swift` | `make()`. Unter Tests liefert jeder Aufruf einen frischen Speicher im Arbeitsspeicher, siehe Warnung in `IntentExecutionTests`. |
| `LooseEndsTests/IntentExecutionTests.swift` | Muster für Intent-Tests: `perform()` direkt aufrufen. Ob die Aufgabe im Speicher ankommt, ist dort bewusst nicht prüfbar. |
| `project.yml` | `Shared/` wird in LooseEnds (iOS + macOS), Widgets (iOS + macOS), Share (iOS) **und Watch (watchOS)** übersetzt. Es gibt kein eigenes App-Intents-Extension-Target, obwohl ADR-9 eines nennt. |
| `.github/workflows/ci.yml` | Läuft auf `macos-26` mit **Xcode 26.6** und senkt die Ziele auf 26.0. |
| `docs/project/00-entscheidungen.md` (ADR-9), `02-datenmodell-und-ansichten.md` (Abschnitt „App Intents und Spotlight"), `04-stand.md` (Prio 5) | Vorgaben und Stand. |

## Existing Patterns
- Intents leben in `Shared/Intents/`, sind `@MainActor` in `perform()` und öffnen den Container über
  `ModelContainerFactory.make()`. Die Erfassung läuft über `CaptureService.save(…, via: .siri, …)`.
- Abhängigkeiten von iOS 27 werden mit `#available` geschützt, Frameworks mit `#if canImport(...)`
  (Beispiel: `FoundationModelsEnricher`).
- Plattformcode in `Shared/` wird mit `#if os(...)` abgegrenzt, weil `Shared/` auch in watchOS übersetzt wird.
- Tests mit Swift Testing (`@Test`, `#expect`), Container in einem lokalen Wert halten (CLAUDE.md).

## Dependencies
- Upstream: AppIntents (iOS-27-SDK), `CaptureService`, `TaskActions`, `RevisionService`/`FieldCodec`,
  SwiftData-Modell.
- Downstream: Siri und Kurzbefehle (System), Spotlight (`IndexedEntity`, falls übernommen). Die bestehende
  Phrase „Add to Loose Ends" muss weiter funktionieren.

## Existing Specs
- Keine Spec zu Intents. Thematisch nahe: `docs/specs/fix-202-titel-regel.md` (Titel beim Erfassen).

## Risks & Considerations
1. **CI übersetzt nicht.** Mit Xcode 26.6 existieren `@AppIntent(schema:)` und `.reminders` nicht.
   `#available` wirkt erst zur Laufzeit und reicht deshalb nicht.
   - Nötig ist ein Schalter beim Übersetzen, z. B. `#if compiler(>=6.4)` (Xcode 27 = Swift 6.4).
   - Oder zuerst **#178** (CI auf das Image `xcode-27`), danach entfällt der Schalter.
   - Die Wahl zwischen beiden fällt in der Analyse.
2. **watchOS:** Die Domäne gibt es auf watchOS nicht. Die Schema-Typen brauchen `#if !os(watchOS)`.
3. **Rohtext gegen strukturierte Siri-Felder.**
   - Siri liefert schon zerlegte Felder: `title`, `dueDate`, `recurrence`, `list`, `note`.
   - Laut ADR ist der Rohtext unveränderlich und die Quelle aller abgeleiteten Felder.
   - Offen ist, was als `rawText` gespeichert wird (nur `title`? `title` + `note`?) und ob `dueDate`
     bzw. `recurrence` von Siri übernommen werden (mit welcher Herkunft: Regel, Siri, Nutzer?)
     oder verworfen werden, damit unsere Regeln sie aus dem Rohtext ableiten.
   - Beispiel: „Erinnere mich morgen an X" kommt als `title` „X" plus `dueDate` an. Der Rohtext allein
     verliert dabei das Datum. Diese Frage geht an den PO.
4. **`deleteReminders` widerspricht „Nothing is deleted"** (Revisions, ADR). Möglich ist Parken oder
   Erledigt statt Löschen, sonst entfällt der Intent.
5. **`createList` legt Projekte an.** Projektnamen sind nicht eindeutig (#157 deckt nur Kontexte ab).
   Ein per Siri angelegtes Doppel wäre möglich.
6. **Pflicht-Liste.**
   - `reminder.list` ist Pflicht, aber Aufgaben ohne Projekt sind bei uns der Normalfall.
   - Nötig ist eine virtuelle Eingangsliste („Loose Ends"), sonst lässt sich die Entity nicht befüllen.
7. **Umfang gegen Scoping-Limit.**
   - Entity Reminder, Entity List, Query und 4 Intents samt Tests sprengen voraussichtlich ±250 LoC.
   - Schnitt-Kandidat: zuerst `createReminder` mit Reminder- und List-Entity (Lesezugriff),
     danach `update`, `delete` und `createList` als ein gebündeltes Folgeticket.
8. **Gerätestufe Pflicht:** `Shared/Intents/` steht auf der Pfadliste. Siri-Verhalten zeigt der
   Simulator nur eingeschränkt. Ein Nachweis per Unit-Test über `perform()` ist möglich, das echte
   Siri-Routing nicht.
9. **Kein App-Intents-Extension-Target.**
   - ADR-9 sagt „läuft in der App-Intents-Extension", gebaut ist das nicht.
   - Ein neues Target würde `project.yml`, Entitlements und Info.plist berühren, also mehr Risiko.
   - Heute laufen die Intents im App-Prozess. Ob das so bleibt, klärt die Analyse.
10. **Datumsauslegung:** `dueDate` kommt als `DateComponents`. Die Abbildung auf
    `dueDate`/`dueHasTime` folgt der Uhrzeit-Komponente.

## Analysis

### Type
Feature

### Befund aus dem Compiler-Spike (2026-10-05, Xcode 27.0 / Swift 6.4)
Die Wegwerf-Datei lag im Scratchpad und gehört nicht ins Repo.
- **Kompiliert ohne Fehler auf iOS 27 und macOS 27:**
  - `@AppEnum(schema: .reminders.listType)` mit nur `case standard` und `caseDisplayRepresentations`.
  - `@AppEntity(schema: .reminders.list)` mit `id: String`, `name`, `type`.
  - `@AppEntity(schema: .reminders.reminder)` mit `id: UUID`, `title`, `list`.
  - `@AppIntent(schema: .reminders.createReminder)` mit nur `title`, Rückgabe `ReturnsValue<ReminderEntity>`.
  - Alle übrigen Schema-Felder sind also optional.
- **Die Entities brauchen eigene Initialisierer.** Das Makro macht aus den Feldern `EntityProperty`, der
  automatisch erzeugte Initialisierer nimmt dann keine einfachen Werte mehr an.
- **watchOS:** Der Compiler meldet `'reminders' is unavailable in watchOS`. Die ganze Datei braucht
  `#if !os(watchOS)`.
- **CI mit Xcode 26.6:** Dort fehlen die Typen. `#available` hilft nicht, weil schon das Übersetzen
  scheitert. Möglich ist `#if compiler(>=6.4)` (bereits so in `Measurement/MeasurementRun.swift:228`)
  oder zuerst #178.
- **Regelschritt:** `EnrichmentCoordinator.applyDueDateRule` (Zeile 172) bricht ohne Treffer ab und löscht
  kein vorhandenes Datum. Ein Datum, das Siri liefert, bleibt also stehen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Intents/ReminderSchema.swift` | CREATE | `ListKind`, List-Entity (virtuelle Eingangsliste „Loose Ends“ mit fester ID `inbox` plus Projekte), Reminder-Entity (`id`, `title`, `list`, `isCompleted`, `creationDate`, `dueDate` nur lesend), Queries über `entities(for:)` und `CreateReminderIntent`. Die ganze Datei steht in `#if !os(watchOS)`. |
| `Shared/Services/CaptureService.swift` | MODIFY | `save` nimmt optional ein Fälligkeitsdatum und ein Projekt entgegen. Das Datum wird mit Revision (Autor `ai`, Grund „Siri“) und Konfidenz 1.0 gesetzt. Es bleibt der einzige Schreibweg. |
| `LooseEndsTests/ReminderSchemaTests.swift` | CREATE | Abbildungen als reine Funktionen über einen `ModelContext` testen: Rohtext, Datum aus `DateComponents` (mit und ohne Uhrzeit), Projekt nach ID, unbekannte Liste führt in die Eingangsliste, Entity aus `TaskItem`, Query nach IDs einschließlich erledigter und geparkter Aufgaben. |
| `LooseEndsTests/IntentExecutionTests.swift` | MODIFY | Ein Test, der `CreateReminderIntent.perform()` aufruft (gleiches Muster wie die bestehenden Tests). |
| `docs/project/04-stand.md` | MODIFY | #25 als gebaut eintragen und auf das Folgeticket verweisen. |

`CaptureTextIntent.swift` und die Phrase „Add to Loose Ends“ bleiben unverändert.

### Scope Assessment
- Files: 4 Code- und Testdateien plus 1 Doku-Datei
- Estimated LoC: etwa +220/−5
- Risk Level: MEDIUM
  - Der neue Code ist isoliert.
  - Die Makros erzeugen Code, den man nicht sieht.
  - Ob Siri die Anfragen tatsächlich zur App leitet, zeigt nur das Gerät.

### Technical Approach
1. **Reihenfolge: zuerst #178 (CI auf das Image `xcode-27`), dann #25, ohne Schalter beim Übersetzen.**
   - Mit `#if compiler(>=6.4)` würde die CI das ganze Feature nie übersetzen und trotzdem grün melden.
   - Beim Vorbild in `MeasurementRun` sind es wenige Zeilen, hier wäre es das ganze Feature.
   - #174 hat das Image für TestFlight schon erprobt.
   - Ausweichweg, falls #178 hängt: `#if compiler(>=6.4) && !os(watchOS)` mit Verweis auf #178.
2. **Schnitt 1 = `createReminder` mit Reminder- und List-Entity.**
   - `updateReminder`, `deleteReminders`, `createList`, Wiederholung, Markierung, Tags, URLs und
     Spotlight (`IndexedEntity`) kommen in **ein** gebündeltes Folgeticket.
   - `deleteReminders` wird dort zu Parken, weil nichts gelöscht wird. `createList` braucht dort eine
     Namensprüfung analog #157.
3. **Rohtext = Siris `title`, dazu `note` in einer neuen Zeile, falls vorhanden.**
   - `TitleRule` nimmt den Titel aus der ersten Zeile.
   - Es gibt keinen synthetischen Text im Rohtext (ADR-3).
   - Den Vorschlag, das Datum als Text anzuhängen und vom Regel-Parser wieder auslesen zu lassen,
     habe ich verworfen: Im Rohtext stünde dann etwas, das der Nutzer nicht gesagt hat, und das Datum
     würde einmal durch Text und zurück übersetzt.
4. **Siris `dueDate` wird direkt übernommen.**
   - Quelle `ai`, Konfidenz 1.0, Revision mit Autor `ai` und Grund „Siri“. Das entspricht dem Muster
     von `DueDateRule`.
   - `dueHasTime` ist genau dann wahr, wenn `hour` gesetzt ist.
   - Ohne Modell geht es hier nicht anders: Siri entfernt das Datum aus dem Titel, deshalb kann keine
     Regel es aus dem Rohtext wiederfinden. Siri liefert es aber schon strukturiert. Es braucht also
     keine Regel, sondern nur eine Abbildung.
5. **Liste.**
   - Projekt nach ID: Die Aufgabe kommt in das Projekt.
   - Eingangsliste oder keine Liste: kein Projekt.
   - Unbekannte Liste: Eingangsliste. In Schnitt 1 legt Siri kein Projekt an.
6. **Query.**
   - `FetchDescriptor<TaskItem>` mit `ids.contains($0.id)` auf `@MainActor`.
   - Erledigte und geparkte Aufgaben werden mit aufgelöst.

### Alternativen
- **A: Kein Schema, nur mehr eigene Phrasen** (etwa „Erinnere mich in Loose Ends …“).
  - Rund 30 Zeilen, keine Abhängigkeit von iOS 27 oder der CI.
  - Siri leitet allgemeine Erinnerungen dann aber nicht zur App, jede Phrase braucht den App-Namen.
  - Verfehlt das Ziel von #25 und kippt die Siri-Zeile von ADR-9.
- **B: Schnitt 1 ohne Listen-Zuordnung.** Jede Aufgabe landet in der Eingangsliste, rund 30 Zeilen
  weniger. Die Bitte „in meiner Liste X“ würde dann stillschweigend ignoriert.
- **C: Siris Datum verwerfen, nur Regeln.** Das ist am reinsten nach „Regeln vor Modell“, verliert aber
  bei „Erinnere mich morgen an X“ das Datum ersatzlos.
- **D: Ein eigenes App-Intents-Extension-Target, wie ADR-9 es nennt.** Das berührt `project.yml`,
  Entitlements und Info.plist. Für Schnitt 1 nicht nötig, weil die Intents heute im App-Prozess laufen.
  Die ADR-Zeile bleibt Arbeitsstand.

### Dependencies
- Vorher: #178 (CI auf Xcode 27).
- Upstream: AppIntents (SDK für iOS und macOS 27), `CaptureService`, `TitleRule`, SwiftData-Modell
  (`TaskItem`, `Project`), `ModelContainerFactory`.
- Downstream: Siri und Kurzbefehle. `EnrichmentCoordinator` läuft danach wie bei jeder Erfassung.
- Gerätestufe ist Pflicht (`Shared/Intents/` steht auf der Pfadliste).

### Open Questions
- [x] Reihenfolge #178 zuerst? Technisch entschieden: ja.
- [x] Wohin mit Siris Datum? Technisch entschieden: direkt übernehmen, Rohtext bleibt unberührt.
- [x] Rohtext bei Siri-Erfassung: Es gibt keine Wahl. Das Schema liefert den gesprochenen Satz nicht, nur
  die Felder (`title`, `note`, `dueDate` …). Bei „Erinnere mich morgen an Milch kaufen“ zeigt der Rohtext
  deshalb „Milch kaufen“ und das Datum steht im Fälligkeitsfeld. Die Spec führt das als bekannte
  Eigenschaft auf.
