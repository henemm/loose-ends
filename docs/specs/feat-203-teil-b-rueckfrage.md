---
entity_id: feat-203-teil-b-rueckfrage
type: feature
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: bug-203-kalender-termin
---

# Spec: #203 Teil B — Rückfrage „In den Kalender“ und Zeile „Termin“

## Approval

- [x] Freigegeben: Henning, 2026-10-05 (Gestaltung im Issue-Kommentar) und 2026-10-07 („fang mit Teil B an“)

## Purpose

Henning (#203): „Kalender hinzufügen“ ließ ihn im Unklaren, was im Kalender landet. Entscheidung vom
2026-10-05: keine stille Annahme, sondern eine Rückfrage. Teil A (Konto, Zielkalender sichtbar) ist
in `main` (#230). Teil B fragt beim Einschalten nach, was dem Termin noch fehlt, und zeigt danach
die Zeile „Termin“. Teil C (Zielkalender je Aufgabe) folgt.

## Verhalten (Acceptance Criteria)

- **AC-1 Nur fragen, was fehlt.** Beim Einschalten von „Im Kalender anzeigen“ fehlt dem Termin
  - das **Datum** (keine Fälligkeit),
  - die **Zeitart** (keine Uhrzeit: ganztägig oder zu einer Uhrzeit?),
  - die **Dauer** (Uhrzeit gesetzt, Dauer nicht).
  Fehlt nichts, gibt es keine Rückfrage, der Schalter geht direkt an.
- **AC-2 Sheet „In den Kalender“** mit Abbrechen und „Eintragen“.
  - Datum fehlt → Datumswahl zuerst, vorbelegt mit morgen.
  - Keine Uhrzeit → Wahl „Ganztägig“ / „Zu einer Uhrzeit“. Die zweite fragt danach Uhrzeit und Dauer.
  - Uhrzeit ohne Dauer → Dauer wählen (5 Min., 15 Min., 30 Min., 1 Std., 2 Std.+), daneben der
    Zeitraum, z. B. „14:00–15:00“.
  - „Eintragen“ bleibt aus, bis alles Nötige gewählt ist.
- **AC-3 Die Antwort setzt die Felder an der Aufgabe** als Nutzer-Revision (Fälligkeit, Dauer) und
  schaltet den Schalter ein. „Abbrechen“ lässt ihn aus und ändert nichts.
- **AC-4 Zeile „Termin“** unter dem Schalter, solange der Schalter an und ein Termin planbar ist:
  „Di., 6. Okt. · 14:00–15:00“ oder „Fr., 9. Okt. · ganztägig“.
- **AC-5** Bestehende Hinweise bleiben (z. B. „Calendar access is off in Settings.“). Deutsche Texte
  im String-Katalog.

## Regel statt Modell

Kein Modell. Die Lücken ergeben sich aus `dueDate`, `dueHasTime` und `duration` der Aufgabe.

## Source

- **Neu:** `Shared/Services/CalendarAsk.swift` — rein: `gaps(for:)`, `isComplete`, `apply`
- **Neu:** `LooseEnds/Views/CalendarAskSheet.swift` — das Sheet
- **Geändert:** `LooseEnds/Views/TaskDetailView.swift` — Schalter fragt nach, Zeile „Termin“
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` — neue Texte
- Tests: `LooseEndsTests/CalendarAskTests.swift` (neu); angepasst: `CaptureSmokeTests.testCalendarSwitchStaysOn`,
  `CalendarTargetTests.testSwitchOnShowsTargetCalendar` (beide schalten jetzt über das Sheet ein)

## Tests

- **Unit** (`CalendarAskTests`): Lücken je Zustand (nichts gesetzt, nur Datum, Datum+Uhrzeit ohne
  Dauer, alles gesetzt → keine Lücke); `isComplete` je Wahl; `apply` setzt Fälligkeit mit Uhrzeit
  und Dauer als Nutzer-Revision, ganztägig ändert ein vorhandenes Datum nicht, ein unvollständiges
  `apply` ändert nichts.
- **UI:** Beide bestehenden Kalender-Tests laufen durch das Sheet; sie sind der Durchlauf als Nutzer.

## Abnahme

Kein Pfad der Geräteliste berührt (`Shared/Services`, `LooseEnds/Views`). Stufe 1 CI, Stufe 2 UI-Tests
im Simulator.

## Nicht-Scope

Zielkalender wählbar und neues Feld am `TaskItem` (Teil C); Änderungen an `CalendarBridge`.
