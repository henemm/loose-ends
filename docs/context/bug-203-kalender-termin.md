# Context: bug-203-kalender-termin

## Request Summary
„Im Kalender anzeigen“ legt auf Hennings iPhone keinen Termin an, und es ist nicht erkennbar, in
welchen Kalender er ginge. Fix der Ursache plus Gestaltung aus dem Issue-Kommentar vom 2026-10-05:
Rückfrage-Sheet „In den Kalender“ nur für Fehlendes (Datum, Uhrzeit/ganztägig, Dauer), Zielkalender
je Aufgabe änderbar (Standard „Loose Ends“), im Detail die Zeilen „Termin“ und „Kalender“.

## Befund bis hierher (2026-10-06)
- Sauberer Simulator (iOS 27, nur lokale Quelle „Auf meinem iPhone“): Schalter an → Zugriffsdialog →
  „Vollen Zugriff erlauben“ → Kalender „Loose Ends“ wird angelegt, Termin eingetragen
  (Log `calaccessd`: `Calendar (add: 1)`, `Event (add: 1)`). Der Grundweg funktioniert.
- Henning (2026-10-06): iPhone mit **iCloud und Google**, **kein** Kalender „Loose Ends“ vorhanden.
  Der Kalender wurde also nie angelegt.
- `CalendarBridge.appCalendar()` legt „Loose Ends“ in `store.defaultCalendarForNewEvents?.source` an.
  Ist der Standardkalender ein Google-Kalender, verweigert EventKit das Anlegen
  (`EKError.sourceDoesNotAllowCalendarAddDelete`, Code 17). Der Fehler landet nur im Log
  (`Calendar sync failed`), der Nutzer sieht nichts, der Schalter bleibt an.
- Recherche: Google- und Exchange-Quellen erlauben Apps kein Anlegen/Löschen von Kalendern;
  Empfehlung: iCloud- oder lokale Quelle zuerst suchen
  ([EKError.Code](https://developer.apple.com/documentation/eventkit/ekerror/code),
  [Expo-Forum: „That account does not allow calendars to be added or removed“](https://forums.expo.dev/t/cannot-add-calendar-to-a-real-ios-device-when-it-works-on-an-ios-simulator/32714),
  [EventKit-Muster: writable Local/iCloud source first](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.9.0/files/skills/eventkit/references/eventkit-patterns.md),
  [TN3152 Calendar access levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)).
  Für iOS 27 keine Änderung an `requestFullAccessToEvents` gefunden.

## Nachstellung im Simulator (2026-10-06, 17:41)
Wegwerf-Kopie: `appCalendar()` per Umgebungsvariable auf eine Quelle ohne Anlegerecht gezwungen
(abonnierte Quelle, Stellvertreter für Google, das der Simulator nicht hat), App frisch installiert,
Zugriff zurückgesetzt, Ablauf als Nutzer: Erfassen „… morgen um 15 Uhr“ → Detail → Schalter an →
„Vollen Zugriff erlauben“. Ergebnis: Schalter bleibt an, kein Kalender, kein Termin, keine Meldung.
Log: `Failed to save calendar: EKErrorDomain Code=11` → `Calendar sync failed: …`. Der Simulator
liefert bei der abonnierten Quelle Code 11 statt Code 17 (Google); der Mechanismus ist derselbe:
`saveCalendar` wirft, `sync()` bricht ab, nur ein Logeintrag. Patch danach zurückgenommen.

**Ursache:** `appCalendar()` wählt die Quelle des Standardkalenders, ohne auszuweichen, wenn diese
keine neuen Kalender zulässt, und der Fehler wird dem Nutzer nicht gezeigt.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Calendar/CalendarBridge.swift` | EventKit: Zugriff, `appCalendar()` (Ursache), `sync()`, Fehler nur geloggt |
| `Shared/Services/CalendarSync.swift` | Reine Planung: `plan(for:)` (Zeitregel stimmt schon), `length(of:)`, `changes(in:)` |
| `LooseEnds/Views/TaskDetailView.swift` | Schalter „Show in calendar“, Fußnote `calendarNote` |
| `Shared/Models/TaskItem.swift` | `showInCalendar`, `calendarEventID`; neues Feld für Zielkalender muss optional sein (CloudKit) |
| `LooseEnds/App/ContentView.swift` | `syncSoon()` nach `ModelContext.didSave`, `sync()` beim Start |
| `Shared/Services/RevisionService.swift` | `set(...)` = Nutzer-Revision für Uhrzeit/Dauer aus der Rückfrage |
| `Shared/Services/FieldCodec.swift` | Kodierung von `dueDate`/`duration` |
| `LooseEndsTests/CalendarSyncTests.swift` | Bestehende Unit-Tests der Planung |
| `LooseEndsUITests/CaptureSmokeTests.swift` | `testCalendarSwitchStaysOn` (unter `--ui-testing`, Brücke dort stumm) |
| `docs/project/00-entscheidungen.md` | ADR-13 Kalender |

## Existing Patterns
- Reine Logik in `Shared/Services` (enum mit statischen Funktionen), EventKit nur in `LooseEnds/Calendar`.
- Nutzeränderung an abgeleiteten Feldern immer über `RevisionService.set` (Revision, author `.user`).
- Systemdialoge/Berechtigungen unter Tests stumm (`ModelContainerFactory.isRunningTests/isUITesting`).
- Sheets im Detail: `FieldEditorView`, Änderungen-Sheet.

## Dependencies
- Upstream: EventKit (`EKEventStore`, `EKCalendar`, `EKSource`), SwiftData.
- Downstream: Detailansicht (Fußnote), ContentView (Abgleich-Auslöser).

## Risks & Considerations
- Simulator hat keine Google-Quelle; Nachstellung über eine Quelle ohne Anlegerecht (abonniert).
- Neues Feld am `TaskItem` (Zielkalender-Kennung) optional, CloudKit-kompatibel. Kalender-Kennungen
  sind je Gerät verschieden → Kennung plus Titel merken oder pro Gerät auflösen.
- `calendarEventID` ist ebenfalls gerätespezifisch (bestehendes Risiko bei Mac + iPhone, nicht Teil
  dieses Tickets).
- Scoping 4–5 Dateien / ±250 LoC: Fix + Sheet + Zeilen + Kalenderwahl ist eher größer → Schnitt prüfen.
- Geräteliste: keine der Pfade, solange `project.yml`/`Info.plist` unverändert bleiben.

## Analysis

### Type
Bug (Ursache) plus Feature (Gestaltung aus dem Issue-Kommentar vom 2026-10-05).

### Lieferung in drei Teilen (Scoping-Limits; Vorbild #101 Teil A/B)
| Teil | Inhalt | Dateien | LoC (geschätzt) |
|------|--------|---------|-----------------|
| **A** (dieser Workflow) | Ursache: Kalender „Loose Ends“ wird in einer Quelle angelegt, die das zulässt (iCloud → lokal → Quelle des Standardkalenders → übrige CalDAV; Exchange, abonniert, Geburtstage nie), bei Ablehnung nächste Quelle. Scheitert alles: sichtbarer Hinweis unter dem Schalter statt stillem Log. Dazu Zeile „Kalender · ● Name“ (Lesen, noch ohne Wahl), damit der Zielkalender sofort erkennbar ist. | `Shared/Services/CalendarSync.swift`, `LooseEnds/Calendar/CalendarBridge.swift`, `LooseEnds/Views/TaskDetailView.swift`, `LooseEndsTests/CalendarSyncTests.swift` | ~130 |
| **B** | Rückfrage-Sheet „In den Kalender“ (nur Fehlendes: Datum, ganztägig/Uhrzeit, Dauer; Abbrechen lässt Schalter aus; Antwort = Nutzer-Revision) und Zeile „Termin“ | neues `LooseEnds/Views/CalendarAskSheet.swift`, `TaskDetailView.swift`, `CalendarSync.swift`, Tests, UI-Test | ~220 |
| **C** | Zielkalender je Aufgabe änderbar (optionales Feld `TaskItem.calendarName`, Auflösung je Gerät über den Titel, Termin wandert bei Wechsel mit, Aufräumen über alle verwendeten Kalender) | `TaskItem.swift`, `CalendarBridge.swift`, `CalendarSync.swift`, Auswahl-View, Tests | ~200 |

Reihenfolge A → B → C. A allein behebt Hennings Fehler. C schließt #203.

### Technical Approach (Teil A)
- Reine Funktion `CalendarSync.sourceOrder(_:defaultID:)` über `SourceCandidate {id, title, kind}`
  (EKSource lässt sich im Test nicht bauen); iCloud wird am Titel „iCloud“ erkannt, weil Google
  ebenfalls `.calDAV` ist. Die Brücke bildet `EKSource` darauf ab und probiert der Reihe nach.
- Bestehender Kalender (gemerkte Kennung oder Titel „Loose Ends“) bleibt unangetastet — die
  Ausweichlogik greift nur beim Anlegen.
- `CalendarBridge` bekommt einen beobachtbaren Problemzustand (`noWritableSource`), die Fußnote zeigt
  ihn; der Schalter wird nicht automatisch zurückgesetzt.
- Test rot→grün: `sourceOrder` mit Google als Standard + iCloud vorhanden → iCloud zuerst, Google
  nicht vor iCloud; nur Google/Exchange → leere bzw. Google-only-Liste.

### Risiko
Niedrig–mittel: betrifft nur das Anlegen des eigenen Kalenders; vorhandene Kalender/Termine bleiben.
Geräteliste: kein Pfad berührt (kein `project.yml`, keine `Info.plist`, keine Berechtigungsänderung).

### Alternative (verworfen)
Systemdialog `EKEventEditViewController` bzw. reiner Schreibzugriff: das System wählt den Kalender,
kein Anlegen eines eigenen Kalenders nötig. Kippt ADR-13: die App könnte ihre Termine nicht mehr
wiederfinden, aktualisieren oder entfernen; jede Aufgabe bräuchte einen Speichern-Tipp.
Bewusst nicht gewählt, weil der PO den Zielkalender „Loose Ends“ mit Änderbarkeit entschieden hat.

### Open Questions
- keine (Gestaltung vom PO am 2026-10-05 entschieden; Entwurf auf der Design-Leinwand freigegeben)
