---
entity_id: feat-203-teil-c2-standardkalender
type: feature
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: bug-203-kalender-termin
---

# Spec: #203 Teil C2 — Standardkalender je Gerät

## Approval

- [x] Entwurf freigegeben: Henning, 2026-10-12 (Abschnitt „Kalender“ in den Einstellungen)

## Purpose

Entscheidungen vom 2026-10-09: Der Standard für neue Termine ist änderbar, **je Gerät**, in eigenen
Einstellungen. Die Einstellungen hinter dem Zahnrad gibt es seit #311; C2 ergänzt dort einen Abschnitt.
C1 (Kalender je Aufgabe) ist in `main` (#365) und auf dem Gerät abgenommen (Build 49).

## Verhalten (Acceptance Criteria)

- **AC-1 Abschnitt „Kalender“** in den Einstellungen (iPhone, iPad: Blatt hinter dem Zahnrad; Mac: ⌘,):
  Zeile „Neue Termine in · ● Name ›“. Tipp öffnet die Kalenderliste aus C1, „Loose Ends · Standard“ oben.
  Fußzeile: „Gilt nur auf diesem Gerät. Eine Aufgabe behält den Kalender, den sie beim Einschalten bekommt.“
- **AC-2 Je Gerät.** Gespeichert in den Geräteeinstellungen (`UserDefaults`), Kontoname und Kalendername.
  „Loose Ends“ wählen löscht den Wert.
- **AC-3 Beim Einschalten.** Wird „Im Kalender“ an einer Aufgabe ohne eigene Wahl eingeschaltet (direkt oder
  über die Rückfrage aus Teil B), bekommt sie den Standard dieses Geräts als ihre Wahl und behält ihn auf
  allen Geräten. Ist der Standard „Loose Ends“, bleibt die Aufgabe ohne Wahl.
- **AC-4 Standard fehlt auf dem Gerät.** Gibt es den gewählten Standard hier nicht (mehr), gehen neue Termine
  nach „Loose Ends“; die Zeile zeigt den Namen ohne Farbpunkt, Fußzeile „Gibt es auf diesem Gerät nicht.
  Neue Termine gehen nach „Loose Ends“.“
- **AC-5 Ohne Kalenderzugriff** ist die Zeile ausgegraut, Fußzeile „Steht zur Wahl, sobald eine Aufgabe im
  Kalender steht.“ Das Öffnen der Einstellungen fragt nie nach Zugriff.
- **AC-6 Freigabetext** (aus C1 offen): `NSCalendarsFullAccessUsageDescription` sagt, dass Termine in
  „Loose Ends“ oder einem gewählten Kalender landen und die App nur ihre eigenen Termine ändert.
- **AC-7** Deutsche Texte im String-Katalog.

## Scope

`Shared/Services/CalendarSync.swift` (Standard lesen/schreiben, Übernahme beim Einschalten),
`Shared/Services/CalendarAsk.swift`, `LooseEnds/Calendar/CalendarBridge.swift`, `LooseEnds/Views/SettingsView.swift`,
`LooseEnds/Views/TaskDetailView.swift`, `LooseEnds/App/LooseEndsApp.swift`, `project.yml`, `LooseEnds/Info.plist`,
`Localizable.xcstrings`, Unit-Tests. Kein neues Modellfeld.

## Abnahme

Unit-Tests, CI mit UI-Smoke. `project.yml`/`Info.plist` stehen auf der Geräteliste: Stufe 3 über TestFlight.
Henning stellt auf dem iPhone den Standard um, schaltet „Im Kalender“ an einer neuen Aufgabe ein und sieht den
Termin im gewählten Kalender; auf dem Mac bleibt dessen eigener Standard.
