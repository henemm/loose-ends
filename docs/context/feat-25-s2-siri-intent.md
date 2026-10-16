# Context: feat-25-s2-siri-intent

## Request Summary
#25 Schnitt 2: Siri legt Aufgaben über Apples Reminders-App-Schema an (`reminders.createReminder`). Der Intent
übersetzt die SDK-Typen in `SiriCapture.Input` (Schnitt 1, gemergt als #432), ruft `prepare`/`commit` auf und
liest bei jedem Fehler einen eigenen Satz vor (Deutsch und Englisch). „Add to Loose Ends“ über `CaptureTextIntent`
bleibt unverändert. Stufe 3 (Gerät) ist Pflicht, weil `Shared/Intents/` berührt wird. Schnitt 3 (Ändern, Parken,
Liste anlegen) folgt. Ausgeliefert wird #25 erst nach #240.

## Stand der Zweige
- Schnitt 1 steht auf `main` (`70d03f5`, PR #432). Der alte Zweig `feat-25-siri-neubau` trug nur die zwei Einzelcommits davor.
- Neuer Zweig `feat-25-s2-siri-intent` von `origin/main`.
- Sicherung `origin/wip/25-siri-sicherung`: Patch mit `Shared/Intents/ReminderSchema.swift` (222 Zeilen), Änderung an
  `CaptureService`, zwei Testdateien. Stand vom 2026-10-12, vor Schnitt 1 geschrieben; `04-stand.md`-Teil weglassen.
  `origin/wip/25-siri-red-tests`: RED-Tests `ReminderSchemaTests` (318 Zeilen) und `IntentExecutionTests`.
- Laut Kontext von Schnitt 1 kompilierte der Sicherungs-Code am 2026-10-15 auf aktuellem `main` im Simulator-Bau.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/SiriCapture.swift` | `Input` (reines Struct), `prepare` (async, wirft vor dem Schreiben), `commit` (MainActor), `Geocode`-Typ injiziert, `SiriCaptureError` (Enum mit 9 Fällen) — der Intent ruft das auf |
| `Shared/Intents/CaptureTextIntent.swift` | Heutiger Siri-Weg `CaptureTextIntent` + `AppShortcutsProvider`; muss unverändert bleiben (AC-7) |
| `Shared/Services/CaptureService.swift` | `save` bleibt unverändert (AC-8); die WIP-Änderung (`titleFrom`, `due`, `project`) wird **nicht** übernommen, Schnitt 1 hat das über `SiriCapture` gelöst |
| `Shared/Services/SiriFields.swift`, `SiriRepeatMapping.swift` | Link, Markierung, Tags, Wiederholung; Fehler fließen als `SiriCaptureError` heraus |
| `Shared/Models/TaskPlace.swift`, `PlaceEditing.swift` | Ort: Name, Koordinate, Ereignis `arrive`/`depart` |
| `project.yml` (Zeilen 123, 198, 228f) | `Intents/*` sind pro Target einzeln aufgeführt; neue Dateien müssen ins App-Target, nicht in Widget- und Share-Targets. `AppShortcuts.xcstrings` liegt im App-Target. **`project.yml` steht auf der Geräteliste** |
| `docs/project/02-datenmodell-und-ansichten.md:281` | beschreibt `TaskEntity`/Schema; wird an die Umsetzung angepasst |
| `docs/specs/intents/feat-25-s1-siri-capture.md` | Spec Schnitt 1 mit Out-of-Scope-Liste für Schnitt 2 |
| Kommentar in #25 (2026-10-08, Cloud-Entwurf) | Vorlage mit AC-6/AC-7, Risiken U1–U6, DoD je Schnitt |

## Existing Patterns
- Zwei Schritte „prüfen, dann schreiben“; keine Siri-Typen in `Shared/Services`, die Übersetzung gehört in den Intent.
- Der heutige Intent baut seinen Container selbst: `ModelContainerFactory.make()` + `ModelContext`, `@MainActor perform()`.
- WIP-Entwurf: Schema-Typen (`ListEntity`, `ReminderEntity`, `LocationTriggerEntity`, `SectionEntity`, `CreateReminderIntent`)
  hinter `#if compiler(>=6.4) && !os(watchOS)`; die Domäne gibt es ab iOS/macOS 27, nicht auf watchOS.
  Der Guard war für CI mit Xcode 26 gedacht. Seit #174/#178 läuft CI auf Xcode 27, Deployment Target 27: der Guard ist
  vermutlich überflüssig und wird in der Analyse geprüft (Rest bleibt: `!os(watchOS)`).
- Fehler für Siri: `CustomLocalizedStringResourceConvertible` am Fehler-Enum (in `Shared/Intents`, nicht in `Services`,
  wegen `AppIntents`), Texte in String Catalog.

## Dependencies
- Upstream: `SiriCapture`, `ModelContainerFactory`, `CatalogService` (Projekte nach `nameKey`), `CLGeocoder`/MapKit für die Adresse (Produktpfad des `Geocode`).
- Downstream: Siri/Spotlight; `AppShortcutsProvider` (muss `CaptureTextIntent` weiter anbieten).

## Existing Specs
- `docs/specs/intents/feat-25-s1-siri-capture.md`, `feat-225-siri-link-flag-tags.md`, `docs/specs/feat-226-ortserinnerungen.md`.

## Risks & Considerations
- **SDK weicht von U1–U6 ab** (Feldtypen, Pflichtfelder des Schemas, `PlaceDescriptor`/`GeoToolbox`). Abgleich mit dem echten SDK vor der Spec.
- **Pflicht-Entitäten des Schemas** (`locationTrigger`, `section`) müssen existieren, auch wenn Loose Ends sie nicht eigen verwaltet; Abschnitt/Bilder lehnt `SiriCapture` sichtbar ab (F5).
- **Datum als `DateComponents` (U3):** liefert der Intent nur Datum ohne Stunde, ist `hasTime == false`.
- **Gerätestufe Pflicht** (`Shared/Intents/`, `project.yml`): Siri-Diktat auf dem Gerät. Nichts auf Hennings Geräten ohne sein wörtliches „jetzt ist ein Test möglich“; Weg über TestFlight (#279-Regel). Vorher alles bauen.
- **Siri im Hintergrund:** Startzeit des Prozesses ungemessen (Risiko 4 der Cloud-Spec).
- **Umfang:** WIP war ~220 Zeilen Schema-Code plus Intent-Übersetzung und Fehlertexte; Grenze 250 LoC / 4–5 Dateien könnte reißen → in der Analyse zuschneiden oder weiter teilen.
- **Mehrere Sitzungen:** Vor dem Schnitt `origin/main` und offene PRs prüfen (Lehre aus #368).
- **Neue Datei im Projekt:** nach Änderung `./scripts/sim.sh generate`; Tests nur über `sim-unit`, nie `unit`.

## Analysis

### Type
Feature (Schnitt 2 von 3 für #25). Ohne Modell: Alles hier ist Übersetzung strukturierter Siri-Felder in `SiriCapture.Input`, deterministisch. „Without the model this fails because …“ entfällt, es wird kein Modell vorgeschlagen.

### Recherche (vor allem anderen, 2026-10-15)
- Schema `.reminders.createReminder` existiert ab iOS/iPadOS/macOS/visionOS 27, **nicht auf watchOS** (Apple-Doku `AppSchema/RemindersIntent/createReminder`, bestätigt in `AppIntents.swiftinterface` des iPhoneOS27.0-SDK: `@available(watchOS, unavailable)`).
  Pflichtfelder laut Doku: `title`, `list`, `note: AttributedString?`, `isFlagged`, `images: [IntentFile]`, `tags: Set<String>`, `urls`, `dueDate: DateComponents?`, `recurrence: Calendar.RecurrenceRule?`, `locationTrigger`, `section`. Rückgabe `ReturnsValue<ReminderEntity>`.
- Das SDK kennt fünf Entitäten (`group`, `list`, `reminder`, `section`, `locationTrigger`) und zwei Enums (`listType`, `locationTriggerEvent`). Der WIP-Entwurf deckt alle bis auf `group` ab; `group` verlangt `createReminder` nicht.
- **Siri nimmt das Schema nur mit Apple Intelligence.** Ohne sie läuft weiter der alte SiriKit-Weg `INAddTasksIntent` (Forum 838792, Antwort mit „accepted“). Ein DTS-Fall (Forum 844505) zeigt: Siri lehnt trotz korrektem Code mit „I can't add items directly to <App>“ ab, Shortcuts zeigt den Intent richtig an; Apple verweist auf Feedback-Meldung, keine Lösung. **Risiko für die Gerätestufe liegt außerhalb unseres Codes.**
- `PlaceDescriptor` (GeoToolbox) trägt Darstellungen `.address(String)`, `.coordinate(CLLocationCoordinate2D)`, `.serviceIdentifiers`, dazu `commonName`: deckt sich mit `SiriCapture.Place` (Name, Adresse, Koordinate).

### Stand des Sicherungs-Entwurfs (`origin/wip/25-siri-sicherung`)
Taugt als Vorlage für die Schema-Typen (~220 Zeilen), **nicht** zum Übernehmen im Ganzen:
- `ReminderMapping.capture` und die `CaptureService`-Änderung (`titleFrom`, `due`, `project`) sind durch Schnitt 1 (`SiriCapture`) ersetzt und entfallen. Die RED-Tests `ReminderSchemaTests` (318 Z.) und `IntentExecutionTests` testen genau diesen entfallenen Pfad und sind **hinfällig**; neue Tests gegen `SiriCapture.Input`.
- Der Guard `#if compiler(>=6.4)` entfällt (CI und Deployment Target laufen auf Xcode 27 / iOS 27). `!os(watchOS)` bleibt nötig, weil die Watch alles aus `Shared/` mitkompiliert.
- `LocationTriggerEntity` / `SectionEntity` im Entwurf lösen nie etwas auf (leere Queries). Das genügt für „Siri gibt einen Ort mit“ nicht: Siri muss den Ort **mitliefern**, und der Intent muss ihn aus `place` + `event` lesen. Ob Siri die Entität selbst konstruiert oder über die Query sucht, ist ungeklärt und nur am Gerät sichtbar (Risiko U-Ort).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Intents/ReminderSchema.swift` | CREATE | `ListEntity`, `ReminderEntity`, `LocationTriggerEntity`, `SectionEntity`, `ListKind`, `LocationTriggerEvent`, Queries (ID- und Namenssuche, liest über `ModelContainerFactory`) |
| `LooseEnds/Intents/ReminderTranslation.swift` | CREATE | reine Übersetzung SDK-Typen → `SiriCapture.Input` (DateComponents → Date + `hasTime`, `PlaceDescriptor` → `Place`, `AttributedString` → String, Liste → `listName`, Abschnitt/Bilder durchreichen) |
| `LooseEnds/Intents/CreateReminderIntent.swift` | CREATE (Schnitt 2b) | `@AppIntent(schema:)`, `perform`: `prepare` → `commit` → `ReminderEntity`; echter `Geocode` |
| `LooseEnds/Intents/SiriCaptureError+Dialog.swift` | CREATE (Schnitt 2b) | `CustomLocalizedStringResourceConvertible` für alle 9 Fälle, Texte de/en im String Catalog |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY (2b) | Fehlertexte |
| `LooseEndsTests/ReminderTranslationTests.swift`, `ReminderEntityTests.swift` | CREATE | Übersetzung, Entität aus `TaskItem`, Queries |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Abschnitt App Intents an die Umsetzung anpassen |

Ablageort `LooseEnds/Intents/` statt `Shared/Intents/` ist die Empfehlung: Der App-Ziel-Ordner `LooseEnds/` wird nur von der App (iPhone, iPad, Mac) kompiliert. Das erspart `!os(watchOS)`-Schutz und, was schwerer wiegt, **jede Änderung an `project.yml`** (Widget und Share schließen `CaptureTextIntent` heute einzeln aus, #326: Erfassung nur im App-Prozess). Muss die Spec per Bau belegen.

### Scope Assessment
- Gesamt: 6 Quelldateien + 2–3 Testdateien, **~450 LoC**: über der Grenze (4–5 Dateien, ±250 LoC).
- **Empfehlung: zwei Teil-Specs** (Lehre #368):
  - **Schnitt 2a (dieser Workflow):** `ReminderSchema.swift` + `ReminderTranslation.swift` + Tests, ~230 LoC, 4 Dateien. Kein Intent, nichts für Siri sichtbar, vollständig im Simulator-Unit-Test belegbar. Stufe 3 entfällt hier („Kein Pfad der Geräteliste berührt“, sofern `project.yml` unberührt bleibt).
  - **Schnitt 2b:** Intent, Fehlerdialoge de/en, echter Geocoder, Gerätestufe über TestFlight.
- Risk Level: **MEDIUM** (2a: niedrig, rein additiv; 2b: mittel, Siri-Verhalten am Gerät nicht in unserer Hand).

### Technical Approach
1. 2a baut Entitäten und Übersetzung; `ReminderEntity` ist nur lesbar, Schreiben geht ausschließlich über `SiriCapture`.
2. Liste: `ListEntity` = Projekt; „Loose Ends“ ist die virtuelle Eingangsliste. Eine **unbekannte Liste legt ein Projekt an** (Schnitt 1, F2), anders als im Entwurf (dort: Eingang).
3. Datum: `DateComponents` ohne Stunde → `dueHasTime == false`; unvollständig (ohne Jahr/Monat/Tag) → kein Datum, keine Fehlermeldung (Entscheidung in der Spec festhalten).
4. Ort: `LocationTriggerEntity` trägt `PlaceDescriptor` + Ereignis; Übersetzung nimmt Koordinate vor Adresse, Adresse geht an den Geocoder aus 2b.
5. Abschnitt und Bilder erreichen `SiriCapture` unverändert und werden dort sichtbar abgelehnt (F5).
6. `CaptureTextIntent` und `AppShortcutsProvider` bleiben unangetastet (AC-7 aus #25).

### Alternativen (Pflicht)
- **A: Gar kein Schema, nur `CaptureTextIntent` + alter SiriKit-Weg `INAddTasksIntent`** (Intents-Extension). Vorteil: greift auch auf Geräten **ohne Apple Intelligence**, nutzt das Verfahren, das heute ohne App-Namen funktioniert (Forum 838792). Nachteil: ältere, schmalere Felder, kein Ort/Wiederholung wie im Schema, zweites Ziel mit Signierung. Es würde ADR-9 kippen („Siri über Schema“). **Nicht anstelle, sondern als Rückfall ergänzend zu prüfen**; als eigenes Ticket anlegen (siehe unten), weil Hennings Tester ohne Apple Intelligence sonst keine Siri-Erfassung hätten.
- **B: Schema nur mit `title` + `dueDate` + `list`**, übrige Felder weglassen: unmöglich, das Schema verlangt alle Felder; sie lassen sich nur sichtbar ablehnen (Schnitt 1 tut das bereits).
- **C: Entwurf wie gesichert übernehmen** (ein Schnitt, `CaptureService`-Umbau): verworfen, doppelt zu Schnitt 1 und sprengt die Grenzen.

### Befunde, die gegen den Plan sprechen
- Siri-Annahme am Gerät ist ungesichert (Forum 844505): selbst ein korrekter Intent kann von Siri verweigert werden. Maßnahme: 2b führt die Gerätestufe **zuerst mit einem leeren Intent** (nur Titel), bevor die übrigen Felder gebaut werden. Zeigt sich Ablehnung, stoppt 2b, bevor Aufwand entsteht.
- Ohne Apple Intelligence greift das Schema nie (siehe A).
- Mehrere Sitzungen: offene PRs #434–#436, #444, #445 betreffen Views, nicht `Shared/Intents` oder `LooseEnds/Intents`; `origin/main` hat nichts Neues seit dem Zweigpunkt. Kein Überschneidungsrisiko erkennbar.

### Dependencies
`SiriCapture` (Schnitt 1, gemergt), `ModelContainerFactory`, `CatalogService`, `TaskPlace`, `GeoToolbox` (Systembibliothek, keine neue Abhängigkeit im Sinne der Regel; trotzdem in der Spec nennen). #25 wird erst nach #240 ausgeliefert.

### Open Questions
- [ ] Liegt `LooseEnds/Intents/` wirklich außerhalb von Watch-, Widget- und Share-Ziel und baut ohne `project.yml`-Änderung (Spec belegt per `sim.sh build`)?
- [ ] Unvollständiges Datum: stillschweigend ignorieren oder als Fehler vorlesen? Empfehlung: ignorieren (wie im Entwurf).
- [ ] Wie liefert Siri `LocationTriggerEntity` (konstruiert vs. Query)? Nur am Gerät, in 2b.
