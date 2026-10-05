---
entity_id: feat-25-reminders-schema
type: feature
created: 2026-10-05
updated: 2026-10-05
status: draft
workflow: feature-25-siri-reminders-schema
---

# Spec: #25 — Siri-Erfassung über das Reminders-App-Schema, Schnitt 1 (createReminder)

## Approval

- [ ] Approved

## Purpose

ADR-9 legt fest, dass Siri Aufgaben erfasst. Heute geht das nur über die eigene Phrase „Add to Loose
Ends“ (`CaptureTextIntent`). Sagt Henning „Erinnere mich morgen an Milch kaufen“, ohne den App-Namen zu
nennen, leitet Siri das an Apples Erinnerungen-App, nicht an Loose Ends. Apple bietet ab iOS/macOS 27 für
genau diesen Fall das App-Schema der Domäne `reminders` an (Recherche und Quellen:
`docs/context/feature-25-siri-reminders-schema.md`: Apple-Doku, WWDC26 Session 240, home-assistant/iOS
PR #5660, Mindwtr #915). Apps, die das Schema erfüllen, erscheinen in Siri und Kurzbefehlen; bei
mehreren Anbietern zeigt das System Ergebnis-Reiter.

Schnitt 1 setzt nur die Erfassung um: `createReminder`. Weil dessen Rückgabe `ReturnsValue<ReminderEntity>`
ist und die Reminder-Entity eine Pflicht-Liste (`list`) trägt, gehören zwei Entities (Reminder, List) mit
Queries dazu. Alle übrigen Aktionen der Domäne sind ein gebündeltes Folgeticket (siehe Out of Scope).

**Kein Modell beteiligt.** Die CLAUDE.md-Pflichtzeile „Without the model this fails because …“ entfällt,
weil diese Spec kein Sprachmodell vorschlägt. Siri liefert Titel, Notiz, Liste und Datum schon
strukturiert; Schnitt 1 bildet diese Felder nur auf das Modell ab, ohne Auslegung. Die Regel- und
Modellstufen der Anreicherung laufen danach unverändert wie bei jeder Erfassung. Nulllinie: Das von Siri
gelieferte Datum wird nicht neu berechnet, die Abbildung kann also nichts erfinden; ein Datum, das Siri
nicht liefert, bleibt leer.

**Bekannte Eigenschaft (technisch entschieden, nicht wählbar):** Das Schema liefert den gesprochenen Satz
nicht, nur die Felder. „Erinnere mich morgen an Milch kaufen“ wird zu Rohtext „Milch kaufen“; das Datum
steht im Fälligkeitsfeld mit KI-Marker und Revision „Siri“. Der Rohtext ist bei Siri-Erfassung also
„Titel (plus Notiz)“, nicht der Satz, wie ihn der Nutzer sprach.

## Source

- **File:** `Shared/Services/CaptureService.swift`
- **Identifier:** `CaptureService.save` (einziger Schreibweg für neue Aufgaben; Zeile 12–26)
- **File:** `Shared/Intents/CaptureTextIntent.swift`
- **Identifier:** `CaptureTextIntent`, `LooseEndsShortcuts` — bleiben unverändert, Vorbild für `perform()`
- **File:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Identifier:** `applyDueDateRule` (Zeile 172–193), `applyRules` (Zeile 157)
- **File:** `Shared/Services/TitleRule.swift`
- **Identifier:** `TitleRule.title(from:)` (nimmt die ersten 12 Wörter des **gesamten** Textes, nicht die erste Zeile)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Shared/Services/CaptureService.swift` | module | einziger Schreibweg, wird um optionales Datum, Projekt und Titelquelle erweitert |
| `Shared/Services/TitleRule.swift` | module | Titel bei der Erfassung (#202), **unverändert** |
| `Shared/Models/TaskItem.swift` | model | `id: UUID` (stabile Entity-ID), `rawText`, `title`, `dueDate`, `dueHasTime`, `dueSourceRaw`, `dueConfidence`, `project`, `status`, `completedAt`, `capturedAt` |
| `Shared/Models/Project.swift` | model | „Projects are lists“ (ADR-8), `id: UUID`, `name`, `sortOrder`, `archivedAt`; Quelle der List-Entities |
| `Shared/Models/Revision.swift` | model | Revision mit Autor `ai`, Grund „Siri“ (Muster: `applyDueDateRule`) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | module | läuft nach der Erfassung wie immer; **unverändert** (Entscheidung 4) |
| `Shared/Persistence/ModelContainerFactory.swift` | module | `make()` für `perform()`, unverändert |
| AppIntents (SDK 27) | framework | `.reminders`-Schema: `createReminder`, `reminder`, `list`, `listType` |
| GitHub #178 | Vorbedingung | CI auf das Image `xcode-27`; ohne es übersetzt die CI die neue Datei nicht (Entscheidung 7) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|--------------|
| `Shared/Intents/ReminderSchema.swift` | CREATE | `ListKind` (`@AppEnum`, nur `standard`), `ListEntity`, `ReminderEntity`, deren Queries, `CreateReminderIntent`, reine Abbildungsfunktionen. Ganze Datei in `#if !os(watchOS)` |
| `Shared/Services/CaptureService.swift` | MODIFY | `save` nimmt optional `dueDate: DateComponents?`, `project: Project?` und `titleFrom: String?`; Datum mit Revision (Autor `ai`, Grund „Siri“), Quelle `ai`, Konfidenz 1.0 |
| `LooseEndsTests/ReminderSchemaTests.swift` | CREATE | Abbildungen und Queries als Unit-Tests über einen `ModelContext` |
| `LooseEndsTests/IntentExecutionTests.swift` | MODIFY | ein Test, der `CreateReminderIntent.perform()` aufruft |
| `docs/project/04-stand.md` | MODIFY | #25 als Schnitt 1 gebaut eintragen, auf das Folgeticket verweisen (nur Issue-Nummern, kein Umfang) |

`CaptureTextIntent.swift`, die Phrase „Add to Loose Ends“, `TitleRule`, `project.yml`, Entitlements und
Info.plists bleiben unverändert.

### Estimated Changes
- Files: 5 (1 Produktivcode neu, 1 Produktivcode geändert, 2 Tests, 1 Doku)
- LoC: ca. +220/−5; jede Funktion höchstens 50 Zeilen
- Risk Level: MEDIUM — der neue Code ist isoliert, aber die Makros erzeugen unsichtbaren Code, und ob
  Siri Anfragen tatsächlich an die App leitet, zeigt nur das Gerät.

### Out of Scope → Folgeticket
Ein **gebündeltes Folgeticket** (gemeinsames Ziel: „Rest der Reminders-Domäne“; wird bei der Umsetzung als
GitHub-Issue angelegt, nicht als Liste in Markdown):
- `updateReminder` (u. a. `isCompleted` über `TaskActions`, Feldänderungen als `Revision`)
- `deleteReminders` als `DeleteIntent` — wird **Parken**, weil nichts gelöscht wird („Revisions, not undo“)
- `createList` mit Namensprüfung analog #157 (Projektnamen sind heute nicht eindeutig)
- Wiederholung (`recurrence` → `RepeatRule`), Markierung (`isFlagged`), Tags, URLs, Bilder
- Spotlight (`IndexedEntity`)

Siri legt in Schnitt 1 **kein** Projekt an.

## Implementation Details

### 1. Datei und Plattform

`Shared/Intents/ReminderSchema.swift` steht vollständig in `#if !os(watchOS)`: Der Compiler meldet
`'reminders' is unavailable in watchOS` (Spike 2026-10-05, Xcode 27.0 / Swift 6.4), und `Shared/` wird
auch in die Watch übersetzt. Die Typen sind ab iOS/macOS 27 verfügbar; das Deployment Target ist 27, ein
`#available` ist nicht nötig.

### 2. List-Entity

```swift
@AppEnum(schema: .reminders.listType)
enum ListKind: String, AppEnum { case standard /* + caseDisplayRepresentations */ }

@AppEntity(schema: .reminders.list)
struct ListEntity { var id: String; var name: String; var type: ListKind /* + eigener init, Query */ }
```

- **Virtuelle Eingangsliste:** Name „Loose Ends“, feste ID `inbox`. Sie ist die Liste jeder Aufgabe ohne Projekt.
- **Projekte:** ID = `project.id.uuidString`, Name = `project.name`, Typ `standard`.
- **Query:** `entities(for:)` löst `inbox` und Projekt-IDs auf (auch archivierte), unbekannte IDs werden
  ausgelassen. `suggestedEntities()` liefert die Eingangsliste zuerst, dann die nicht archivierten Projekte
  nach `sortOrder`.
- Die Entity braucht einen eigenen Initialisierer: Das Makro macht die Felder zu `EntityProperty`, der
  erzeugte Initialisierer nimmt keine einfachen Werte mehr an (Spike-Befund).

### 3. Reminder-Entity

```swift
@AppEntity(schema: .reminders.reminder)
struct ReminderEntity { var id: UUID; var title: String; var list: ListEntity
                        var isCompleted: Bool; var creationDate: Date; var dueDate: DateComponents? }
```

- Abbildung aus `TaskItem`: `id = task.id`, `title = task.displayTitle`, `list` = Projekt oder `inbox`,
  `isCompleted = (task.status == .done)`, `creationDate = task.capturedAt`, `dueDate` aus `task.dueDate`
  (Stunde und Minute nur, wenn `dueHasTime`). Die Entity ist **nur lesend**. Alle übrigen Schema-Felder
  (`note`, `tags`, `urls`, `recurrence`, `isFlagged`, `completionDate`, `locationTrigger`) sind laut Spike
  optional und werden in Schnitt 1 nicht deklariert.
- **Query:** `entities(for:)` mit `FetchDescriptor<TaskItem>` und `ids.contains($0.id)` auf `@MainActor`.
  Erledigte und geparkte Aufgaben werden mit aufgelöst, unbekannte IDs ausgelassen.

### 4. `CreateReminderIntent`

```swift
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderIntent {
    var title: String; var list: ListEntity?; var note: AttributedString?; var dueDate: DateComponents?
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<ReminderEntity>
}
```

Die übrigen Parameter des Schemas (`isFlagged`, `images`, `tags`, `urls`, `recurrence`, `locationTrigger`,
`section`) werden in Schnitt 1 nicht deklariert, soweit das Schema sie als optional zulässt (Spike: kompiliert
mit nur `title`); sie gehören ins Folgeticket. `perform()` öffnet den Container über
`ModelContainerFactory.make()`, löst die Liste auf, ruft `CaptureService.save(…, via: .siri, …)` und liefert
die Entity der neuen Aufgabe zurück.

### 5. Abbildungsregeln (rein, ohne Modell)

1. **Rohtext:** Siris `title`; ist eine nicht leere `note` vorhanden, folgt sie nach einem Zeilenumbruch
   (`title + "\n" + note`, `note` als reiner Text). `CaptureService` trimmt wie immer. Es gibt keinen
   synthetischen Text im Rohtext (ADR-3): Das Datum wird nicht als Text angehängt und vom Parser wieder
   gelesen, das hätte etwas in den Rohtext geschrieben, das der Nutzer nicht sagte. Ist der Titel leer
   (nur Leerraum), wirft `CaptureService` wie bisher `CaptureError.emptyText`.
2. **Titel:** `TitleRule.title(from:)` nimmt die ersten zwölf Wörter des **gesamten** Textes und macht
   Zeilenumbrüche zu Leerzeichen; sie nähme also die Notiz in den Titel auf. Deshalb übergibt der Intent
   Siris `title` als `titleFrom`, und `save` setzt `item.title = TitleRule.title(from: titleFrom ?? text)`.
   Ohne `titleFrom` (alle bisherigen Aufrufer) bleibt das Verhalten wie heute. `TitleRule` selbst ändert sich nicht.
3. **Datum:** Siris `dueDate` (`DateComponents`) wird mit `Calendar.current` zu einem `Date`. Fehlen Jahr,
   Monat oder Tag, ergibt das **kein Datum** und keine Revision. `dueHasTime` ist genau dann `true`, wenn
   `hour` gesetzt ist (fehlende `minute` zählt als 0). Gesetzt werden `dueDate`, `dueHasTime`,
   `dueSourceRaw = ai`, `dueConfidence = 1.0` und eine `Revision` (Feld `.dueDate`, `oldValue` nil,
   `newValue` ISO-8601 wie im Regelschritt, Autor `ai`, Grund „Siri“). Das entspricht dem Muster von
   `applyDueDateRule`; Konfidenz 1.0, weil nichts geschätzt wurde.
4. **Liste:** `inbox` oder keine Liste → kein Projekt. ID eines vorhandenen Projekts → Aufgabe im Projekt.
   Unbekannte ID (z. B. Projekt inzwischen gelöscht) → Eingangsliste, kein Fehler, kein neues Projekt.
5. **Kanal und Status:** `.siri`; Status bleibt `.unprocessed`, damit der Nachzügler-Lauf der Anreicherung
   die Aufgabe wie jede andere erreicht.

### Entscheidungen

1. **Rohtext = Titel (+ Notiz).** Es gibt keine Wahl: Das Schema liefert den gesprochenen Satz nicht.
   Alternative „Datum als Text anhängen“ verworfen (ADR-3).
2. **Datum direkt übernommen, nicht neu geparst.** Siri entfernt das Datum aus dem Titel; keine Regel kann
   es im Rohtext wiederfinden. Es braucht keine Regel, nur eine Abbildung.
3. **Entities sind nur lesend**, Schreibzugriffe laufen allein über `CaptureService.save`.
4. **Regelschritt und Siri-Datum (im Code geprüft).** `applyDueDateRule` bricht ohne Treffer in
   `DueDateRule.match` ab (`return false`) und löscht kein vorhandenes Datum. Im ersten Lauf
   (`mode: .firstRun`) schreibt die Regel nur bei `task.dueDate == nil` (`firstRun:` an
   `EnrichmentWriter.mayWrite`): Ein Siri-Datum bleibt dort in jedem Fall stehen, auch wenn der Titel selbst
   einen Datumsausdruck enthält. Bei „Neu analysieren“ (#34, `.reanalysis`) darf die Regel ein KI-gesetztes
   Datum durch einen anderen Treffer ersetzen, solange der Nutzer das Feld nie angefasst hat; das gilt für
   jedes KI-Datum, schreibt eine neue Revision und ist hier gewollt. Das Modell hat seit #95 keine
   Fälligkeitsfelder mehr und überschreibt nichts.
5. **Kein App-Intents-Extension-Target** (Alternative D): Die Intents laufen wie heute im App-Prozess.
6. **Wiederholung bleibt draußen.** `recurrence` ist im Schema optional; die Abbildung auf `RepeatRule`
   braucht eigene Regeln und Tests (Folgeticket).
7. **Vorbedingung #178.** #178 (CI auf das Image `xcode-27`) ist zum Zeitpunkt dieser Spec noch **offen**.
   Festlegung: #178 wird vor der Umsetzung erledigt, dann gibt es **keinen Compiler-Schalter**. Begründung:
   Mit `#if compiler(>=6.4)` würde die CI das ganze Feature nie übersetzen und trotzdem grün melden.
   **Ausweichweg**, falls #178 bis `/50-implement` nicht gemergt ist: `#if compiler(>=6.4) && !os(watchOS)`
   um die Datei, mit Kommentar auf #178 (Vorbild: `Measurement/MeasurementRun.swift:228`); die Tests
   bekommen denselben Schalter, und der Schalter fällt mit #178 weg. Die Ticket-Zeile „CI mit älterer SDK
   grün (Guard greift)“ gilt nur für diesen Ausweichweg; auf dem Hauptweg heißt sie „CI übersetzt die Datei
   mit Xcode 27 und führt die Tests aus“.
8. **Titel aus Siris `title`, nicht aus dem ganzen Rohtext**, damit eine Notiz nie in den Titel rutscht
   (Abschnitt 5.2). Alternative, `TitleRule` auf die erste Zeile umzustellen, verworfen: Sie träfe die
   Tests und das Verhalten aus #202 (Zeilenumbruch wird dort bewusst zu Leerzeichen).

### Gerätestufe

**Pflicht.** `Shared/Intents/` steht auf der Pfadliste der Gerätestufe (CLAUDE.md). Das echte
Siri-Routing zeigt nur das Gerät; Simulator und Unit-Test über `perform()` zeigen es nicht.
`./scripts/sim.sh device-status` läuft (liest nur). Henning spricht auf seinem iPhone selbst einen Satz;
Claude wertet aus, ob die Aufgabe mit Titel, Datum und Liste in der App steht und ob Siri Loose Ends als
Ergebnis anbietet.

### Datenänderung

Kein neues Feld, keine Migration, keine AppStorage-Keys, keine neuen Permissions, keine Änderung an
`project.yml`, Info.plist oder Entitlements, kein neues Target, keine Audio-Dateien. Neu sind nur
Intent-Typen und die erweiterte Signatur von `CaptureService.save` (neue Parameter mit Standardwert nil,
bestehende Aufrufer bleiben gültig). Das CloudKit-Schema ändert sich nicht. `TaskItem.id` ist als stabile
ID schon vorhanden („auch für App Intents“, Datenmodell).

## Test Plan

### Automated Tests (TDD RED)

Swift Testing; der `ModelContainer` wird in einem lokalen Wert gehalten (CLAUDE.md).

`LooseEndsTests/ReminderSchemaTests.swift` (Unit, neu):

- [ ] Test 1 (Rohtext Titel): GIVEN Titel „Milch kaufen“, keine Notiz WHEN über die Abbildung erfasst THEN
      `rawText == "Milch kaufen"`, `capturedVia == .siri`, `title == "Milch kaufen"`, `status == .unprocessed`.
- [ ] Test 2 (Rohtext mit Notiz): GIVEN Titel „Milch kaufen“ und Notiz „Hafermilch, 2 Liter“ THEN
      `rawText == "Milch kaufen\nHafermilch, 2 Liter"` (unverändert, beide Teile) und `title == "Milch kaufen"`
      (Notiz nicht im Titel).
- [ ] Test 3 (leerer Titel): GIVEN Titel „   “ WHEN erfasst THEN wirft `CaptureError.emptyText`, keine
      Aufgabe entsteht.
- [ ] Test 4 (Datum ohne Uhrzeit): GIVEN `DateComponents(year: 2026, month: 10, day: 6)` THEN `dueDate` ist der
      6.10.2026, `dueHasTime == false`, `dueSourceRaw == "ai"`, `dueConfidence == 1.0`.
- [ ] Test 5 (Datum mit Uhrzeit): GIVEN `DateComponents(year: 2026, month: 10, day: 6, hour: 15, minute: 30)`
      THEN `dueDate` 6.10.2026 15:30, `dueHasTime == true`; GIVEN `hour: 9` ohne `minute` THEN 9:00 und
      `dueHasTime == true`.
- [ ] Test 6 (unvollständig): GIVEN `DateComponents(hour: 15)`, `DateComponents(month: 10, day: 6)` und
      `DateComponents()` THEN `dueDate == nil`, `dueHasTime == false`, `dueSourceRaw == nil`, keine Revision.
- [ ] Test 7 (Revision): GIVEN ein gültiges Datum THEN genau eine Revision mit Feld `.dueDate`,
      `oldValue == nil`, `newValue` = ISO-8601 des Datums, Autor `ai`, Grund „Siri“.
- [ ] Test 8 (Projekt nach ID): GIVEN ein vorhandenes Projekt „Garten“ WHEN die Liste die ID dieses Projekts
      ist THEN ist `task.project?.id` die Projekt-ID.
- [ ] Test 9 (Eingangsliste): GIVEN die Liste `inbox` und GIVEN keine Liste THEN `task.project == nil`.
- [ ] Test 10 (unbekannte Liste): GIVEN eine UUID, die zu keinem Projekt gehört, und GIVEN ein Text, der
      keine UUID ist THEN `task.project == nil`, die Aufgabe wird gespeichert, es entsteht kein Projekt.
- [ ] Test 11 (Entity aus Aufgabe): GIVEN eine Aufgabe ohne Projekt mit Titel und Datum mit Uhrzeit WHEN die
      `ReminderEntity` gebildet wird THEN `id == task.id`, `title == displayTitle`, `list.id == "inbox"`,
      `list.name == "Loose Ends"`, `isCompleted == false`, `creationDate == capturedAt`, `dueDate` trägt Jahr,
      Monat, Tag, Stunde, Minute; ohne Uhrzeit nur Jahr, Monat, Tag. GIVEN eine Aufgabe im Projekt THEN
      `list.id == project.id.uuidString` und `list.name == project.name`.
- [ ] Test 12 (erledigt): GIVEN `status == .done` THEN `isCompleted == true`; bei `.parked` und `.active`
      `false`.
- [ ] Test 13 (Query nach IDs): GIVEN vier Aufgaben (aktiv, erledigt, geparkt, unbearbeitet) WHEN
      `entities(for:)` mit allen vier IDs THEN vier Entities.
- [ ] Test 14 (unbekannte IDs): GIVEN zwei bekannte und eine unbekannte UUID THEN genau die zwei bekannten.
- [ ] Test 15 (Listen-Query): GIVEN zwei Projekte, eines archiviert WHEN `suggestedEntities()` THEN
      Eingangsliste zuerst, danach nur das nicht archivierte Projekt; `entities(for:)` mit der ID des
      archivierten Projekts liefert es dennoch, mit unbekannter ID nichts.
- [ ] Test 16 (Regelschritt behält Siri-Datum): GIVEN eine per Siri erfasste Aufgabe „Milch kaufen“ mit
      Datum 6.10.2026 WHEN der Regelschritt des `EnrichmentCoordinator` (erster Lauf) läuft THEN bleibt
      `dueDate` 6.10.2026, `dueSourceRaw == "ai"`, und es gibt weiterhin genau eine Datums-Revision.
      GIVEN Titel „Zahnarzt am Freitag“ mit Siri-Datum 6.10.2026 THEN bleibt das Siri-Datum im ersten Lauf
      ebenfalls bestehen (Entscheidung 4). Ist der Regelschritt von außen nicht einzeln aufrufbar, läuft der
      Test über den öffentlichen Nachzügler-Lauf des Coordinators mit einem Enricher ohne Ergebnis.
- [ ] Test 17 (bisheriger Aufruf): GIVEN `CaptureService.save("Rasen mähen", via: .app, in:)` ohne die neuen
      Parameter THEN wie bisher: Titel „Rasen mähen“, kein Datum, keine Revision, kein Projekt.

`LooseEndsTests/IntentExecutionTests.swift` (erweitert):

- [ ] Test 18: GIVEN `CreateReminderIntent` mit Titel „Heckenschere schärfen lassen“, Datum und Liste `inbox`
      WHEN `perform()` aufgerufen wird (Muster `captureTextIntentPerforms`) THEN wirft die Aktion nicht und
      liefert eine `ReminderEntity` mit diesem Titel, `list.id == "inbox"` und dem Datum. Ob die Aufgabe im
      Speicher der App steht, ist hier bewusst nicht prüfbar (Kommentar der Datei: `ModelContainerFactory.make()`
      liefert unter Tests jedes Mal einen frischen Speicher); das decken Tests 1–10 über einen eigenen
      Container ab.

**Keine UI-Tests:** Schnitt 1 ändert keine sichtbare Oberfläche der App; erfasste Aufgaben erscheinen in den
bestehenden, unveränderten Listen. Der sichtbare Teil gehört Siri und der Kurzbefehle-App und ist mit
XCUITest der App nicht prüfbar. Den Ersatz bilden Stufe 2 und 3 der Abnahme.

### Abnahme (Stufen)

1. **Stufe 1 — Tests:** `./scripts/sim.sh unit` grün, alle bestehenden Tests unverändert grün.
2. **Stufe 2 — Simulator:** `./scripts/sim.sh build`, `launch`, `screenshot`. Die App startet. Die Erfassung
   über die Kurzbefehle-App bzw. den Intent im Simulator wird gespielt, soweit der Simulator es zulässt; die
   Aufgabe erscheint in der Liste mit Titel, Datum und Projekt. Beleg per Screenshot, Bilder geöffnet und
   beschrieben, bevor ein Haken fällt. Lässt der Simulator den Aufruf nicht zu, steht das im Bericht, und
   Test 18 ist für diesen Teil der Nachweis.
3. **Stufe 3 — Gerät (Pflicht, wegen `Shared/Intents/`):** `./scripts/sim.sh device-status`. Echtes
   Siri-Routing ist nur dort sichtbar. Henning spricht selbst einen Satz („Erinnere mich morgen an Milch
   kaufen“), Claude wertet aus. Kein nachgespielter Bedienablauf auf dem Gerät (seit dem Rückbau von #153).

## Acceptance Criteria

- **AC-1:** Given Siri ruft `createReminder` mit Titel „Milch kaufen“ auf / When die Aktion läuft / Then
  steht die Aufgabe mit Rohtext „Milch kaufen“, Titel „Milch kaufen“ und Kanal Siri in Loose Ends und
  durchläuft danach die normale Anreicherung (Status zunächst „unprocessed“).
- **AC-2:** Given ein Titel und eine Notiz / When die Aktion läuft / Then enthält der Rohtext beide (Titel
  zuerst, Notiz nach einem Zeilenumbruch), der Titel der Aufgabe stammt nur aus Siris Titel, und der Rohtext
  ist danach unverändert.
- **AC-3:** Given Siri liefert ein Datum ohne Uhrzeit (Jahr, Monat, Tag) / When die Aktion läuft / Then ist
  die Aufgabe an diesem Tag fällig, ohne Uhrzeit, mit KI-Marker, Konfidenz 1.0 und einer Revision mit Autor
  KI und Grund „Siri“.
- **AC-4:** Given Siri liefert ein Datum mit Stunde / When die Aktion läuft / Then ist die Aufgabe zu dieser
  Zeit fällig und `dueHasTime` ist wahr; fehlt die Minute, gilt 0.
- **AC-5:** Given Siri liefert unvollständige Datumsangaben (kein Jahr, Monat oder Tag, oder leer) / When die
  Aktion läuft / Then hat die Aufgabe kein Fälligkeitsdatum und keine Datums-Revision, der Aufruf schlägt
  nicht fehl.
- **AC-6:** Given Siri nennt eine Liste mit der ID eines meiner Projekte / When die Aktion läuft / Then liegt
  die Aufgabe in diesem Projekt.
- **AC-7:** Given Siri nennt die Liste „Loose Ends“ (`inbox`) oder keine Liste / When die Aktion läuft / Then
  hat die Aufgabe kein Projekt.
- **AC-8:** Given Siri nennt eine unbekannte Liste / When die Aktion läuft / Then landet die Aufgabe in der
  Eingangsliste, es entsteht kein neues Projekt, und die Aktion schlägt nicht fehl.
- **AC-9:** Given eine per Siri erfasste Aufgabe mit Datum / When der Regelschritt der Anreicherung zum ersten
  Mal läuft / Then bleibt Siris Datum bestehen (bei „Neu analysieren“ gilt die Regel wie für jedes KI-Datum,
  Entscheidung 4).
- **AC-10:** Given die Antwort der Aktion / When Siri sie liest / Then ist es eine Reminder-Entity mit der ID
  der neuen Aufgabe, Titel, Liste (Pflichtfeld, nie leer), `isCompleted == false`, Erfassungsdatum und Datum.
- **AC-11:** Given die Reminder-Query / When sie IDs erhält / Then löst sie auch erledigte und geparkte
  Aufgaben auf und lässt unbekannte IDs aus. Given die Listen-Query / When Siri Vorschläge holt / Then stehen
  Eingangsliste und nicht archivierte Projekte darin.
- **AC-12:** Given die Phrase „Add to Loose Ends“, `CaptureTextIntent` und alle bisherigen Aufrufe von
  `CaptureService.save` / When sie benutzt werden / Then verhalten sie sich unverändert.
- **AC-13:** Given die Watch-App / When sie gebaut wird / Then enthält sie keine Schema-Typen und übersetzt
  weiter (`#if !os(watchOS)`).
- **AC-14:** Given Henning spricht auf dem iPhone einen Satz („Erinnere mich morgen an Milch kaufen“) / When
  Siri antwortet / Then steht die Aufgabe „Milch kaufen“ mit Datum morgen in der App; ob Siri Loose Ends
  statt der Erinnerungen-App wählt oder anbietet, wird ausgewertet und berichtet (Stufe 3).
- **AC-15 (gesamt):** Given der bestehende Funktionsumfang / When alle Unit- und UI-Tests laufen / Then
  bleiben sie grün, die CI übersetzt die neue Datei mit Xcode 27 (Vorbedingung #178; Ausweichweg siehe
  Entscheidung 7), und `docs/project/04-stand.md` verweist auf #25 und das Folgeticket.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-9 um, ändert keine Entscheidung
- **Rationale:** ADR-9 nennt Siri als Erfassungskanal und das App-Schema als Weg. Schnitt 1 baut den
  Erfassungsteil. Die ADR-9-Zeile „läuft in der App-Intents-Extension“ bleibt Arbeitsstand: Die Intents
  laufen wie heute im App-Prozess, ein eigenes Target wäre für Schnitt 1 nicht nötig und berührte
  `project.yml`, Entitlements und Info.plist.
- **In Alternativen gedacht (mit gekippter Entscheidung):**
  - **A — Kein Schema, nur mehr eigene Phrasen** („Erinnere mich in Loose Ends …“). Rund 30 Zeilen, keine
    Abhängigkeit von iOS 27 oder der CI. Siri leitet allgemeine Erinnerungen dann aber nicht an die App, jede
    Phrase braucht den App-Namen. Verfehlt das Ziel von #25 und kippt die Siri-Zeile von ADR-9.
  - **B — Schnitt 1 ohne Listen-Zuordnung.** Jede Aufgabe landet in der Eingangsliste, rund 30 Zeilen weniger.
    Die Bitte „in meiner Liste X“ würde stillschweigend ignoriert. Kippt: „Projects are lists“ (ADR-8) als
    Brücke zu Siri.
  - **C — Siris Datum verwerfen, nur Regeln.** Am reinsten nach „Regeln vor Modell“, verliert aber bei
  „Erinnere mich morgen an X“ das Datum ersatzlos, weil Siri es aus dem Titel nimmt. Kippt: nichts, es wäre
    nur der schwächere Weg.
  - **D — Eigenes App-Intents-Extension-Target, wie ADR-9 es nennt.** Berührt `project.yml`, Entitlements und
    Info.plist. Für Schnitt 1 nicht nötig. Kippt: die Arbeitsstand-Zeile „läuft in der Extension“ in ADR-9,
    falls es später doch gebraucht wird.
  - **Sunk-cost-Hinweis:** Die bestehende Architektur (eine Intent-Datei, ein Schreibweg) ist kein
    Gegenargument; der Schreibweg `CaptureService.save` bleibt, weil er die Regeln an einer Stelle hält.
- **Folgen:** `ReminderEntity` und `ListEntity` sind die Grundlage für `updateReminder`, `deleteReminders`,
  `createList` und Spotlight im Folgeticket. Ab Schnitt 1 hat die ADR-9-Zeile zu Siri einen gebauten Weg; ob
  Siri ihn wählt, zeigt Stufe 3.

## Changelog

- 2026-10-05: Initial spec created
