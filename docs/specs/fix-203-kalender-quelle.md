---
entity_id: fix-203-kalender-quelle
type: bugfix
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: bug-203-kalender-termin
---

# Spec: #203 Teil A — Der Kalender „Loose Ends“ entsteht in einem Konto, das es erlaubt; Zielkalender sichtbar

## Approval

- [ ] Approved

## Purpose

Henning (#198, #203): „Kalender hinzufügen funktioniert generell noch nicht, und es ist unklar, in
welchen Kalender der Termin geht.“ Sein iPhone hat iCloud und Google; einen Kalender „Loose Ends“
gibt es dort nicht.

**Ursache (nachgestellt im Simulator am 2026-10-06, `docs/context/bug-203-kalender-termin.md`):**
`CalendarBridge.appCalendar()` legt „Loose Ends“ im Konto des Standardkalenders an. Google (wie
Exchange) erlaubt Apps nicht, dort Kalender anzulegen (`EKError.sourceDoesNotAllowCalendarAddDelete`).
`sync()` fängt den Fehler und schreibt ihn nur ins Log. Der Schalter bleibt an, es entsteht weder
Kalender noch Termin, und der Nutzer erfährt nichts.

Teil A behebt die Ursache und macht den Zielkalender sichtbar. Teil B (Rückfrage-Sheet „In den
Kalender“, Zeile „Termin“) und Teil C (Zielkalender je Aufgabe änderbar) folgen als eigene PRs zu
#203, wie im Issue-Kommentar vom 2026-10-05 entschieden.

## Source

- **File:** `LooseEnds/Calendar/CalendarBridge.swift`, **Identifier:** `CalendarBridge.appCalendar()`, `CalendarBridge.sync()`
- **File:** `Shared/Services/CalendarSync.swift`, **Identifier:** `CalendarSync.sourceOrder(_:defaultSourceID:)` (neu)

## Dependencies

| Entity | Art | Zweck |
|--------|-----|-------|
| EventKit (`EKEventStore`, `EKSource`, `EKCalendar`) | Framework | Kalender anlegen, Konten lesen |
| `CalendarSync` | intern | reine Planung, neu: Reihenfolge der Konten |
| `TaskDetailView` | intern, nachgelagert | zeigt Hinweis und Zeile „Kalender“ |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — ADR-13 (eigener Kalender, voller Zugriff) bleibt unverändert; geändert wird nur,
in welchem Konto der eigene Kalender angelegt wird.

## Regel statt Modell

Kein Modell beteiligt. Die Wahl des Kontos ist eine feste Reihenfolge über die Kontoarten.

## Entscheidungen

- Reihenfolge der Konten beim Anlegen: **iCloud → Auf dem Gerät (lokal) → Konto des
  Standardkalenders → übrige CalDAV-Konten.** Exchange, abonnierte Kalender und Geburtstage kommen
  nie in Frage. iCloud wird am Kontotitel „iCloud“ erkannt, weil Google ebenfalls ein CalDAV-Konto
  ist. Quelle der Empfehlung: Apple-Fehlercode `sourceDoesNotAllowCalendarAddDelete`, Erfahrungsberichte
  „That account does not allow calendars to be added or removed“ (Google/Exchange).
- Ein schon vorhandener Kalender „Loose Ends“ (gemerkte Kennung oder Titel) wird weiter benutzt und
  nie verschoben. Die Reihenfolge greift nur beim ersten Anlegen.
- Der Schalter wird bei einem Fehler **nicht** automatisch zurückgesetzt; die Fußnote erklärt.

## Verhalten (Acceptance Criteria)

- **AC-1:** `CalendarSync.sourceOrder(_:defaultSourceID:)` ist eine reine Funktion über
  `CalendarSync.SourceCandidate { id, title, kind }` mit `kind ∈ {calDAV, local, exchange,
  subscribed, birthdays, other}`. Sie liefert die Kennungen in der Reihenfolge oben, jede höchstens
  einmal, ohne Exchange, abonniert und Geburtstage.
  - Google (CalDAV, Standard) + iCloud → iCloud zuerst, Google danach.
  - Nur lokal → lokal.
  - Nur Exchange (Standard) und abonniert → leer.
- **AC-2:** `CalendarBridge` bildet `EKSource` auf `SourceCandidate` ab und versucht das Anlegen in
  dieser Reihenfolge. Scheitert ein Konto, wird der Fehler geloggt (`Logger`, mit Kontotitel) und
  das nächste versucht. Gelingt eines, wird die Kennung wie bisher gemerkt.
- **AC-3:** Scheitert das Anlegen in allen Konten oder gibt es keins, steht unter dem Schalter:
  „Couldn't create the Loose Ends calendar in any of your accounts.“ / „Der Kalender „Loose Ends“
  ließ sich in keinem deiner Konten anlegen.“ Scheitert der Abgleich aus einem anderen Grund, steht
  dort „The calendar couldn't be updated.“ / „Der Kalender ließ sich nicht aktualisieren.“ Der
  Hinweis verschwindet nach dem nächsten erfolgreichen Abgleich.
- **AC-4:** Ist der Schalter an und der Kalender bekannt, zeigt das Detail unter dem Schalter die
  Zeile **„Calendar · ● Loose Ends“** / „Kalender · ● Loose Ends“; der Punkt hat die Systemfarbe des
  Kalenders. In Teil A ist die Zeile nur Anzeige (keine Auswahl, kein Chevron).
- **AC-5:** Die bestehenden Hinweise bleiben: ohne Fälligkeit „Shows up once the task has a due
  date.“, ohne Zugriff „Calendar access is off in Settings.“ Unter Unit-Tests bleibt die Brücke stumm.
  Unter UI-Tests bleibt sie stumm, außer mit dem Startargument `--ui-testing-calendar`.
- **AC-6:** Deutsche Texte im String-Katalog.

## Nicht-Scope

- Rückfrage-Sheet, Zeile „Termin“ (Teil B); Zielkalender wählbar und `TaskItem`-Feld (Teil C).
- Gerätespezifische Termin-Kennungen zwischen Mac und iPhone (`calendarEventID` über CloudKit) —
  bekanntes, eigenes Risiko, nicht Ursache dieses Fehlers.
- Keine Änderung an `project.yml`, `Info.plist` oder Berechtigungstexten.

## Scope

- `Shared/Services/CalendarSync.swift` — `SourceCandidate`, `sourceOrder` (~35 LoC)
- `LooseEnds/Calendar/CalendarBridge.swift` — Anlegen der Reihe nach, Problemzustand, Kalenderinfo
  für die Zeile, Startargument (~60 LoC)
- `LooseEnds/Views/TaskDetailView.swift` — Fußnote, Zeile „Kalender“ (~25 LoC)
- `LooseEnds/Resources/Localizable.xcstrings` — drei Texte
- Tests: `LooseEndsTests/CalendarSyncTests.swift` (+~40), `LooseEndsUITests/CalendarTargetTests.swift` (neu, ~50)

Zählung nach Projektpraxis (#101, #217): drei Produktdateien plus String-Katalog = 4; Testdateien
zählen nicht gegen die Dateigrenze. Gesamt ~210 LoC inklusive Tests, innerhalb ±250.

## Tests

- **Unit (rot vor dem Fix, grün danach):** `CalendarSyncTests` — die drei Fälle aus AC-1, dazu
  „jede Kennung höchstens einmal“ (Standard = iCloud) und „lokal vor fremdem CalDAV-Standard“.
- **UI (echter Weg im Simulator):** `CalendarTargetTests.testSwitchOnShowsTargetCalendar` startet mit
  `--ui-testing --ui-testing-calendar`, erfasst „Zahnarzt morgen um 14 Uhr“, öffnet das Detail,
  schaltet „Show in calendar“ ein, bestätigt den Zugriffsdialog (deutsch oder englisch) und erwartet
  die Zeile „Calendar“ mit „Loose Ends“.
- Der Google-Fall selbst ist im Simulator nicht herstellbar (kein Google-Konto); er ist über
  `sourceOrder` belegt, die Nachstellung mit einem ablehnenden Konto steht im Kontext-Dokument.

## Definition of Done

- [ ] Unit-Tests aus AC-1 vor dem Fix rot, danach grün
- [ ] Alle Unit- und UI-Tests grün, CI grün
- [ ] `test-proof CalendarTargetTests` im Simulator grün; Kalender-App zeigt „Loose Ends“ mit Termin
- [ ] Hinweis aus AC-3 erscheint, wenn kein Konto das Anlegen erlaubt (im Simulator mit einem ablehnenden Konto nachgestellt, wie in der Ursachen-Nachstellung)
- [ ] Deutsche Texte im Katalog

## Abnahme

Kein Pfad der Geräteliste berührt (`LooseEnds/Calendar`, `LooseEnds/Views`, `Shared/Services`).
Stufe 1 CI, Stufe 2 Simulator: `./scripts/sim.sh test-proof CalendarTargetTests` plus Screenshot
der Kalender-App mit „Loose Ends“ und dem Termin.

## Changelog

- 2026-10-06: Erste Fassung (Teil A von #203), nach Nachstellung im Simulator und Hennings Angabe
  „iCloud und Google, kein Kalender Loose Ends“.
