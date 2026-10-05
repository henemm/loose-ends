---
spec_file: docs/specs/intents/feat-25-reminders-schema.md
spec_sha256: 3474399b4ad84f70c23712649ef52d228708c948d9135f1a4f1adb4471c017ed
---

# PO-Briefing: feature-25-siri-reminders-schema

- **Spec:** docs/specs/intents/feat-25-reminders-schema.md
- **Issue:** #25
- **Erstellt:** 2026-10-05

## Was gebaut wird

Siri legt Erinnerungen mit Titel, Datum und Liste direkt in Loose Ends an, auch ohne App-Namen.

## Definition of Done

„Erinnere mich morgen an Milch kaufen“ erzeugt auf deinem iPhone die Aufgabe „Milch kaufen“ mit Datum morgen in Loose Ends.

## Wie geprüft wird

Tests belegen die Übernahme von Titel, Datum und Liste; ob Siri wirklich Loose Ends wählt, zeigt nur dein iPhone.

## Kritische Anmerkungen

- Nur Anlegen kommt jetzt; Ändern, Löschen und Liste anlegen, vom Ticket verlangt, folgen in einem Folgeticket.
- Gespeichert wird nur Titel plus Notiz, nicht der gesprochene Satz.
- Ticket verlangt Absicherung für alte CI; Spec setzt stattdessen offenes Ticket 178 (CI auf Xcode 27) voraus.

## Freigabe-Frage

Gibst du frei, dass zuerst nur das Anlegen per Siri gebaut wird und der Rest später folgt?
