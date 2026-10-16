---
entity_id: feat-25-s2a-schema-entitaeten
type: feature
created: 2026-10-15
updated: 2026-10-15
status: draft
workflow: feat-25-s2-siri-intent
---

# Spec: #25 Schnitt 2a — Schema-Entitäten und Übersetzung für Siri-Erinnerungen

## Approval

- [ ] Approved

## Purpose

Siri legt Erinnerungen über Apples Reminders-Schema an. Dafür verlangt das System Entitäten (Liste, Erinnerung,
Ortsauslöser, Abschnitt) und Aufzählungen (Listenart, Ortsereignis) und liefert seine Angaben als SDK-Typen
(`DateComponents`, `AttributedString`, `PlaceDescriptor`). Schnitt 2a baut diese Entitäten und die reine
Übersetzung der SDK-Typen in `SiriCapture.Input` (Schnitt 1, gemergt). Es gibt **keinen Intent**: Siri sieht
nach diesem Schnitt nichts Neues, die App verhält sich unverändert. Der Intent, die Fehlertexte für Siri und
der Gerätelauf folgen in Schnitt 2b.

**Ohne Modell:** Siri liefert fertig strukturierte Werte; die Übersetzung ordnet sie nur zu (Datum zerlegen,
Ort lesen, Text aus `AttributedString` ziehen). Nichts ist auszulegen, ein Modell wäre nur bei Sprachverstehen
denkbar. Die Regel ist hier der ganze Weg, kein Modell als Alternative nötig.

## Source

- **Datei:** `LooseEnds/Intents/ReminderSchema.swift` (neu): `ListEntity`, `ReminderEntity`,
  `LocationTriggerEntity`, `SectionEntity`, `ListKind`, `LocationTriggerEvent`, ihre Queries
- **Datei:** `LooseEnds/Intents/ReminderTranslation.swift` (neu): `enum ReminderTranslation`,
  Funktion `input(...) -> SiriCapture.Input`
- **Vorlage (nur lesen, nicht übernehmen):** `origin/wip/25-siri-sicherung`,
  `docs/artifacts/feature-25-siri-reminders-schema/wip-stand-2026-10-12.patch`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SiriCapture.Input`, `Place`, `Coordinate` (Schnitt 1) | module | Ziel der Übersetzung; bleibt unverändert |
| `TaskPlace.Event` | model | Ereignis `arrive`/`depart` für `Input.Place.event` |
| `Project`, `TaskItem` | model | Quelle für `ListEntity` und `ReminderEntity` (nur lesend) |
| `ModelContainerFactory.make()` | module | Container für die Queries (Siri ruft sie ohne laufende App) |
| `AppIntents` (`@AppEntity(schema:)`, `@AppEnum(schema:)`) | SDK | Schema `.reminders`, ab iOS/macOS 27, nicht auf watchOS |
| `GeoToolbox` (`PlaceDescriptor`) | SDK | Ort aus Siri; Systembibliothek, keine neue Abhängigkeit im Sinne der Regel |
| `TestStore` (`LooseEndsTests/EnrichmentTests.swift`) | test | hält den Container als Feld |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Intents/ReminderSchema.swift` | CREATE | Entitäten, Aufzählungen, Queries; Erinnerung nur lesbar (ca. 150 LoC) |
| `LooseEnds/Intents/ReminderTranslation.swift` | CREATE | Übersetzung SDK-Typen → `SiriCapture.Input` (ca. 70 LoC) |
| `LooseEndsTests/ReminderTranslationTests.swift` | CREATE | Übersetzung (Tests zählen nicht zur Grenze) |
| `LooseEndsTests/ReminderEntityTests.swift` | CREATE | Entität aus `TaskItem`, Listen- und Erinnerungs-Suche |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Abschnitt App Intents an die Umsetzung anpassen |

### Estimated Changes

- Files: 5 (davon 2 Quelldateien, 2 Testdateien, 1 Dokument)
- LoC: ca. +220/-0 Code ohne Tests, innerhalb der Grenzen (4 bis 5 Dateien, 250 LoC)
- **`project.yml`, Entitlements und Info.plist bleiben unberührt.** Das App-Ziel kompiliert den Ordner
  `LooseEnds/` und `Shared/` als Ganzes (`project.yml` Zeilen 38–40); Watch, Widgets und Share nehmen aus
  `LooseEnds/` nur einzeln aufgeführte Dateien. Der Ordner `LooseEnds/Intents/` liegt damit nur im App-Prozess,
  ohne `!os(watchOS)`-Schutz und ohne Änderung an `project.yml`. Das belegt der Bau (AC-9).

### Out of Scope

- **Schnitt 2b:** `CreateReminderIntent`, `perform`, `prepare`/`commit`-Aufruf, echter Geocoder, Fehlertexte für
  Siri (`CustomLocalizedStringResourceConvertible`, String Catalog de/en), Gerätestufe über TestFlight.
- **Schnitt 3:** Ändern, Parken, Liste anlegen als eigene Siri-Handlung.
- Ablösen oder Ändern von `CaptureTextIntent` und `AppShortcutsProvider` (bleiben unangetastet).
- Änderung an `CaptureService.save` (Entwurf der Sicherung verworfen, Schnitt 1 hat das über `SiriCapture` gelöst).
- Alternative ohne Apple Intelligence (`INAddTasksIntent`): eigenes Ticket, siehe Alternativen.
- Ausgeliefert wird #25 erst nach #240.

## Implementation Details

**Entitäten (nur lesend).** Schreiben geht ausschließlich über `SiriCapture.commit` (2b). Die Entitäten
tragen alles, was das Schema verlangt, auch wenn Loose Ends es nicht eigens verwaltet.

- `ListEntity`: Eine Liste ist ein Projekt (ADR-8). Aufgaben ohne Projekt liegen in der virtuellen Eingangsliste
  „Loose Ends“ (feste Kennung `inbox`). `entities(for:)` löst Eingang und Projekte nach Kennung auf, archivierte
  eingeschlossen, unbekannte werden ausgelassen. `suggestedEntities` liefert Eingang zuerst, dann nicht archivierte
  Projekte nach `sortOrder`. Die String-Suche vergleicht ohne Groß/Klein und Akzente (wie `nameKey`).
- `ReminderEntity`: aus `TaskItem` gebaut (Kennung, Titel `displayTitle`, Liste, erledigt, Anlagedatum, Fälligkeit
  als `DateComponents`). Nicht gelesene Pflichtfelder (`note`, `tags`, `urls`, `recurrence`, `isFlagged`,
  `locationTrigger`) bleiben leer; sie zu füllen ist Sache von Schnitt 3, die Entität wird hier nicht vollständig.
- `LocationTriggerEntity` und `SectionEntity`: Pflicht des Schemas, ihre Queries lösen nichts auf (leer). Ob
  Siri den Ort selbst konstruiert oder über die Query sucht, zeigt nur das Gerät (Risiko U-Ort, Schnitt 2b).

**Übersetzung `ReminderTranslation.input`.** Reine Funktion ohne `ModelContext`, ohne Zugriff auf Container.

| SDK-Feld | `Input`-Feld | Regel |
|---|---|---|
| `title` | `title` | unverändert (Leerprüfung macht `prepare`) |
| `note: AttributedString?` | `notes` | `String(note.characters)`; leer bleibt `nil` |
| `dueDate: DateComponents?` | `due`, `dueHasTime` | Jahr, Monat und Tag nötig, sonst **kein Datum, kein Fehler** (Festlegung unten); Stunde vorhanden → `dueHasTime = true`, Minute fehlt → 0; sonst Datum um 00:00 Ortszeit, `dueHasTime = false` |
| `list: ListEntity?` | `listName` | Name der Liste; Eingangsliste oder `nil` → `nil` (kein Projekt) |
| `recurrence` | `recurrence` | unverändert durchgereicht (`SiriRepeatMapping` entscheidet) |
| `locationTrigger` | `place` | Koordinate vor Adresse: `.coordinate` → `Coordinate`; `.address` → `address`; Name aus `commonName`; Ereignis `arrive`/`depart` → `TaskPlace.Event` |
| `urls`, `isFlagged`, `tags` | gleichnamig | `tags` als Array (Reihenfolge ungeordnet, Menge zählt) |
| `section` | `section` | Name des Abschnitts; `SiriCapture` lehnt Inhalt ab (F5) |
| `images` | `imageCount` | Anzahl |

**Festlegung unvollständiges Datum.** `DateComponents` ohne Jahr, Monat oder Tag ergibt kein Datum und keinen
Fehler (Empfehlung der Analyse, wie im Entwurf). Begründung: Siri löst „morgen“ selbst auf; ein unvollständiges
Datum ist eine Seltenheit, und eine vorgelesene Ablehnung würde die ganze Erinnerung verwerfen. Henning kann
das kippen, die Änderung wäre eine Zeile in der Übersetzung.

**Alternativen.**

- **Kein Schema, nur `CaptureTextIntent` plus alter SiriKit-Weg `INAddTasksIntent`:** greift auch ohne Apple
  Intelligence, hat aber schmalere Felder (kein Ort, keine Wiederholung wie im Schema) und ein zweites Ziel mit
  Signierung; es kippte ADR-9 („Siri über Schema“). Nicht anstelle des Schemas, sondern **ergänzend als Rückfall**.
  Dafür wird ein eigenes Ticket angelegt, damit Tester ohne Apple Intelligence nicht ohne Siri-Erfassung bleiben.
- **Ordner `Shared/Intents/` statt `LooseEnds/Intents/`:** gleicher Code, aber `!os(watchOS)`-Schutz und
  Eingriffe in `project.yml` (Intents werden dort pro Ziel einzeln aufgeführt, Widget und Share schließen sie
  aus, #326). Verworfen; `project.yml` steht außerdem auf der Geräteliste und löste Stufe 3 aus.
- **Entwurf der Sicherung unverändert übernehmen:** verworfen, `ReminderMapping.capture` und die
  `CaptureService`-Änderung sind durch Schnitt 1 ersetzt; dessen RED-Tests prüfen den entfallenen Pfad.

## Test Plan

### Automated Tests (TDD RED)

Swift Testing, Container jeweils lokal über `TestStore`. Ausführung nur über `./scripts/sim.sh sim-unit`.

`LooseEndsTests/ReminderTranslationTests.swift`:

- [ ] `titleAndNoteTranslate`: GIVEN Titel „Steuer“ und Notiz als `AttributedString` „Belege holen“ WHEN
  übersetzt THEN `title == "Steuer"`, `notes == "Belege holen"`; leere Notiz ergibt `nil`.
- [ ] `dateWithoutTimeHasNoTime`: GIVEN 2026-10-20 ohne Stunde WHEN übersetzt THEN `due` ist dieser Tag, `dueHasTime == false`.
- [ ] `dateWithHourHasTime`: GIVEN 2026-10-20 9 Uhr (Minute fehlt) WHEN übersetzt THEN `dueHasTime == true`, 09:00.
- [ ] `incompleteDateIsDropped` (parametrisiert: ohne Jahr, ohne Monat, ohne Tag, nur Stunde): GIVEN
  unvollständige `DateComponents` WHEN übersetzt THEN `due == nil`, `dueHasTime == false`, es wird nichts geworfen.
- [ ] `listNameFromList`: GIVEN `ListEntity` „Büro“ WHEN übersetzt THEN `listName == "Büro"`; GIVEN Eingangsliste oder keine THEN `nil`.
- [ ] `coordinateBeatsAddress`: GIVEN Ort mit Koordinate und Adresse WHEN übersetzt THEN trägt `Place` die Koordinate, die Adresse bleibt als Zusatz.
- [ ] `addressOnlyKeepsAddress`: GIVEN Ort nur mit Adresse WHEN übersetzt THEN `coordinate == nil`, `address` gesetzt.
- [ ] `eventMaps`: GIVEN `arrive` und `depart` WHEN übersetzt THEN `TaskPlace.Event.arrive` und `.depart`.
- [ ] `flagTagsUrlsPassThrough`: GIVEN Markierung, Tags `{a, b}`, zwei Links WHEN übersetzt THEN gleichnamige Felder, Tags als Menge gleich.
- [ ] `sectionAndImagesReachSiriCapture`: GIVEN Abschnitt „X“ und zwei Bilder WHEN übersetzt und `prepare` aufgerufen
  THEN wirft `unsupported(.section)` bzw. `unsupported(.images)` (die Kette schließt, nicht nur die Übersetzung).
- [ ] `translatedInputRunsThroughSiriCapture`: GIVEN vollständig übersetzte Eingabe WHEN `prepare` und `commit` laufen
  THEN entsteht genau eine Aufgabe mit Titel, Datum, Projekt, Ort (der halbe Weg reicht nicht, #136).

`LooseEndsTests/ReminderEntityTests.swift`:

- [ ] `entityFromTask`: GIVEN Aufgabe mit Titel, Projekt, Fälligkeit mit Uhrzeit WHEN `ReminderEntity(task:)` THEN
  Kennung, Titel, Liste und `DateComponents` mit Stunde stimmen; ohne Uhrzeit keine Stunde.
- [ ] `taskWithoutProjectIsInInbox`: GIVEN Aufgabe ohne Projekt WHEN Entität gebaut THEN Liste = Eingang „Loose Ends“.
- [ ] `listEntitiesForIDs`: GIVEN Eingang, aktives und archiviertes Projekt, unbekannte Kennung WHEN
  `entities(for:)` THEN Eingang und beide Projekte, unbekannte ausgelassen.
- [ ] `suggestedListsInboxFirst`: GIVEN drei Projekte, eines archiviert WHEN `suggested` THEN Eingang zuerst, dann
  die zwei aktiven nach `sortOrder`.
- [ ] `listStringSearchIgnoresCaseAndAccents`: GIVEN Projekt „Büro“ WHEN gesucht mit „buro“ THEN gefunden.
- [ ] `reminderEntitiesByIDIncludeDone`: GIVEN offene und erledigte Aufgabe WHEN `entities(for:)` THEN beide.
- [ ] `locationTriggerAndSectionQueriesResolveNothing`: GIVEN beliebige Kennung WHEN gesucht THEN leer.

Kein UI-Test: Es entsteht nichts Sichtbares und kein Aufrufer im Produktpfad. Den echten Siri-Durchlauf belegt 2b.

## Acceptance Criteria

- **AC-1:** Given Siris Titel und eine Notiz als `AttributedString` / When die Übersetzung läuft / Then trägt
  `Input` Titel und Notiz als einfachen Text, und eine leere Notiz ergibt `nil`.
- **AC-2:** Given `DateComponents` mit Jahr, Monat, Tag / When die Übersetzung läuft / Then ist `dueHasTime`
  genau dann wahr, wenn eine Stunde vorhanden ist; fehlt die Minute, gilt 0.
- **AC-3:** Given `DateComponents` ohne Jahr, Monat oder Tag / When die Übersetzung läuft / Then ist `due`
  leer, es wird kein Fehler geworfen, und `dueHasTime` ist falsch.
- **AC-4:** Given eine Liste, die Eingangsliste oder keine Liste / When die Übersetzung läuft / Then ist
  `listName` für die Eingangsliste und für „keine“ leer, sonst der Name der Liste.
- **AC-5:** Given ein Ort aus Siri mit Koordinate, mit Adresse oder mit beidem / When die Übersetzung läuft /
  Then wird die Koordinate vor der Adresse übernommen, eine reine Adresse bleibt ohne Koordinate, und das
  Ereignis kommt als `arrive` oder `depart` an.
- **AC-6:** Given Link, Markierung, Tags, Wiederholung, Abschnitt und Bilder / When die Übersetzung läuft und
  `prepare` aufgerufen wird / Then kommen die Werte unverändert bei `SiriCapture` an, und Abschnitt mit Inhalt
  sowie Bilder werden dort mit `unsupported` abgelehnt.
- **AC-7:** Given eine vollständig übersetzte Eingabe / When `prepare` und `commit` laufen / Then entsteht genau
  eine Aufgabe mit Titel, Datum, Projekt und Ort.
- **AC-8:** Given Aufgaben und Projekte (auch archiviert und erledigt) / When `ListEntity` und `ReminderEntity`
  gebaut und befragt werden / Then löst `entities(for:)` Eingang, Projekte und Aufgaben nach Kennung auf (unbekannte
  ausgelassen), die Vorschlagsliste führt den Eingang vor den nicht archivierten Projekten nach `sortOrder`, die
  Namenssuche ignoriert Groß/Klein und Akzente, und die Erinnerung trägt Titel, Liste, Fälligkeit mit oder ohne Uhrzeit.
- **AC-9:** Given der Stand nach diesem Schnitt / When `./scripts/sim.sh generate` und `build` laufen / Then
  baut die iOS-App im Simulator ohne Änderung an `project.yml`, und die Dateien in `LooseEnds/Intents/` sind in
  keinem Watch-, Widget- oder Share-Ziel (Prüfung des Diffs und der erzeugten Projektdatei).
- **AC-10:** Given der Stand nach diesem Schnitt / When der Diff geprüft wird / Then sind `CaptureService.swift`,
  `CaptureTextIntent.swift` und `SiriCapture.swift` unverändert, und kein Intent mit Schema ist deklariert.

## Abnahme

Abnahme nach Stufe 2 (Tests, Simulator-Start der App). Schnitt 2a berührt keinen Pfad der Geräteliste: `project.yml`,
Entitlements und Info.plist bleiben unverändert, `LooseEnds/Intents/` steht nicht auf der Liste, und es gibt keinen
Intent, den Siri sehen könnte. Begründung im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ Kein Testhinweis
an Henning, nichts auf seinen Geräten. Die Gerätestufe gehört zu Schnitt 2b.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, belegt durch die im Test Plan genannten Tests und den Bau
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`, nie `unit`)
- [ ] Build erfolgreich (`./scripts/sim.sh generate`, dann `build`), jeder Commit kompiliert
- [ ] App im Simulator gestartet und unverändert lauffähig (Stufe 2), Beleg registriert
- [ ] `docs/project/02-datenmodell-und-ansichten.md` (App Intents) angepasst
- [ ] CLAUDE.md „Where things live“ nennt `LooseEnds/Intents`
- [ ] Folgearbeit angelegt: Schnitt 2b im Ticket #25 vermerkt, Rückfall-Ticket `INAddTasksIntent` als eigenes Issue
- [ ] CI grün, Ticket-Board aktuell

## Risiken

1. **Schema-Typen weichen vom SDK ab (U1–U6).** Der Entwurf wurde am 2026-10-12 vor Schnitt 1 geschrieben und
   kompilierte am 2026-10-15 auf `main` im Simulator-Bau. Gegenmaßnahme: AC-9, voller Bau vor Übergabe.
2. **Siri nimmt das Schema nur mit Apple Intelligence an** (Forum 838792) und kann trotz korrektem Code ablehnen
   (Forum 844505). Das trifft erst 2b; 2a baut nichts, was dadurch verloren ginge. Gegenmaßnahme in 2b:
   Gerätestufe zuerst mit einem leeren Intent (nur Titel).
3. **Ortsauslöser: konstruiert oder gesucht?** Nur am Gerät sichtbar; 2a liefert beide Wege (Entität plus leere Query).
4. **Zeitzone und Kalender der `DateComponents`.** Siri kann `calendar` und `timeZone` mitliefern; die Übersetzung
   nimmt den gelieferten Kalender, sonst den aktuellen. Test mit einer Zeitzone ungleich der Gerätezeit.
5. **Mehrere Sitzungen.** Offene PRs betreffen Views; vor dem Merge `origin/main` prüfen (Lehre #368).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Schnitt fügt Entitäten und eine reine Übersetzung hinzu und bewegt sich in bestehenden
  Entscheidungen (ADR-8 Liste = Projekt, ADR-9 Siri über Schema, ADR-3 abgeleitete Felder mit Herkunft).
- **Rationale:** Die Ausführung im App-Prozess statt in einer App-Intents-Extension (Abweichung von ADR-9) wird mit dem
  Intent in Schnitt 2b entschieden, nicht hier.

## Changelog

- 2026-10-15: Initial spec created (Schnitt 2a von 3 zu #25; die Analyse teilte Schnitt 2 in 2a und 2b, weil ca. 450 LoC
  die Grenze von 250 sprengen).
