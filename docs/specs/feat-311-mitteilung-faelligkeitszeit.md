---
entity_id: feat-311-mitteilung-faelligkeitszeit
type: feature
created: 2026-10-11
updated: 2026-10-11
status: implemented
workflow: feat-311-mitteilung-faelligkeitszeit
---

# Spec: #311 — Mitteilung zur Fälligkeitszeit, Uhrzeit ohne Fälligkeitszeit einstellbar

## Approval

- [x] Produktentscheidungen: Henning, 2026-10-10 (Intake, `docs/context/feat-311-mitteilung-faelligkeitszeit.md`)
- [x] Technik: Tech-Lead-Entscheidung 2026-10-11 (unten)

## Purpose

Eine Aufgabe mit Uhrzeit meldet sich genau zu dieser Uhrzeit („Jetzt fällig“), eine Aufgabe ohne Uhrzeit
am Fälligkeitstag zu einer einstellbaren Uhrzeit („Heute fällig“, Standard 9:00). Die Uhrzeit gilt auf
allen Geräten.

## Regeln vor dem Modell

Kein Modell beteiligt: reine Planung aus `dueDate`, `dueHasTime` und der Einstellung.

## Tech-Lead-Entscheidungen

| Frage | Entscheidung | Grund |
|---|---|---|
| Stunde oder Stunde und Minute? | Stunde und Minute (`DatePicker` `.hourAndMinute`) | Kostet nichts extra; „einstellbar“ ohne künstliche Grenze |
| Wo liegt der Wert? | `UserDefaults` (lokal maßgeblich) + Spiegel im iCloud-Schlüsselwertspeicher (`NSUbiquitousKeyValueStore`), Schlüssel `dueReminderMinutes`, Minuten seit Mitternacht | Geräteübergreifend ohne Modelländerung und ohne CloudKit-Deploy. Ohne Berechtigung oder ohne iCloud bleibt der lokale Wert gültig |
| Fremde Änderung | `didChangeExternallyNotification` → Wert übernehmen → neu planen | sonst feuert ein Gerät zur alten Zeit |
| Zeit vorbei | keine Mitteilung (DoD) — auch für eine heute nach der eingestellten Zeit angelegte Aufgabe ohne Uhrzeit | wie bisher; wer eine Erinnerung zu einer Zeit will, gibt die Uhrzeit an |
| Einstieg | Zahnrad in der Werkzeugleiste der Startseite; iPhone/iPad als Blatt mit „Fertig“, Mac per `SettingsLink` ins Einstellungsfenster (⌘,, App-Menü) | PO-Entscheidung |

## Änderungen

| Datei | Änderung |
|---|---|
| `Shared/Notifications/DueReminders.swift` | `Time` (Stunde, Minute, gespeicherte Form mit Rückfall auf 9:00); `plan(for:time:now:calendar:)`: `dueHasTime` → `dueDate`, sonst Tag + `time`; `Reminder.kind` (`.now`/`.today`); `defaultHour` entfällt |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | `reminderTime` (lesen/schreiben, Schreiben plant neu), iCloud-Spiegel und Beobachter, Text je `kind` |
| `LooseEnds/Views/SettingsView.swift` (neu) | Formular „Einstellungen“ → „Mitteilungen“ → Uhrzeit |
| `LooseEnds/App/ContentView.swift`, `LooseEndsApp.swift` | Zahnrad, Blatt, `Settings`-Szene auf dem Mac |
| `LooseEnds/LooseEnds.entitlements` | `com.apple.developer.ubiquity-kvstore-identifier` = `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` |
| `LooseEnds/Resources/Localizable.xcstrings` | „Jetzt fällig“, „Einstellungen“, „Mitteilungen“, Beschriftung, Fußzeile |
| `docs/project/02-datenmodell-und-ansichten.md` | Abschnitt „Mitteilungen“ |

Keine Änderung an `Shared/Models` → kein `mac-schema-init`, kein CloudKit-Deploy.

## Testplan

- Unit (`DueRemindersTests`): mit Uhrzeit → genau diese Zeit, Art `.now`, Einstellung wirkt nicht;
  ohne Uhrzeit → eingestellte Zeit, Art `.today`; Uhrzeit vorbei → keine Mitteilung; gespeicherte Form
  mit Rückfall. Bestehende Fälle (9:00-Standard, #127) bleiben grün.
- Unit (`DueNotificationCenterTests`, #328): was beim System angemeldet wird — Text, Kategorie, Auslösezeit,
  Ersetzen nach Änderung der Uhrzeit, fremde Anfragen bleiben, Übernahme aus iCloud. Ein aufzeichnender
  Ersatz steht für `UNUserNotificationCenter` (`DueScheduling`), dessen `add` im iOS-27-Simulator scheitert.
- UI-Smoke (`SettingsSmokeTests`): Zahnrad öffnet die Einstellungen mit der Uhrzeit, „Fertig“ schließt.
- Simulator-Beleg: Banner per `simctl push` mit `body` „Jetzt fällig“ (`add` scheitert im iOS-27-Simulator).
- Stufe 3 (Pfade `LooseEnds/Notifications/`, `*.entitlements`), über TestFlight:
  1. Aufgabe „in 5 Minuten“ mit Uhrzeit anlegen → Mitteilung „Jetzt fällig“ zur Minute.
  2. Einstellungen → Uhrzeit auf 2 Minuten in der Zukunft, Aufgabe „heute“ ohne Uhrzeit → „Heute fällig“ dann.
  3. Uhrzeit auf dem iPhone ändern → Mac/iPad zeigt nach kurzer Zeit dieselbe Uhrzeit.

## Acceptance Criteria

- **AC-1:** Aufgabe mit Uhrzeit → genau eine Mitteilung zur Fälligkeitszeit, Text „Jetzt fällig“.
- **AC-2:** Aufgabe ohne Uhrzeit → Mitteilung am Fälligkeitstag zur eingestellten Uhrzeit, „Heute fällig“.
- **AC-3:** Zeitpunkt vorbei → keine Mitteilung.
- **AC-4:** Änderung der Uhrzeit plant alle Mitteilungen neu, auf diesem und den anderen Geräten.
- **AC-5:** Ohne gespeicherten Wert gilt 9:00.
