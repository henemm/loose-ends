---
spec_file: docs/specs/enrichment/feat-127-repeat-reminder.md
spec_sha256: 695ad31a63706802eac4bd7a66ad659e5901af20a73d8a57b5bceb2478816e17
---

# PO-Briefing: feat-127-repeat-reminder

- **Spec:** docs/specs/enrichment/feat-127-repeat-reminder.md
- **Issue:** #127
- **Erstellt:** 2026-09-25

## Was gebaut wird

Wird eine Wiederholung neu angelegt, bekommt sie automatisch ein erstes Fälligkeitsdatum, damit Erinnerungen greifen.

## Definition of Done

Fertig, wenn eine neu angelegte Wiederholung ohne Datum automatisch fällig wird und im täglichen Erinnerungs-Push erscheint, sobald sie fällig ist.

## Wie geprüft wird

Automatisierte Tests belegen Datumsberechnung, Übernahme ins Editor-Feld und Erscheinen im Sammel-Push; bestehende unreparierte Altfälle werden nicht getestet.

## Kritische Anmerkungen

- Bestehende Aufgaben mit Wiederholung ohne Fälligkeitsdatum (der gemeldete Fall) bleiben unrepariert, bis jemand die Regel erneut bearbeitet.
- Erinnerung kommt nicht zur eingestellten Uhrzeit, sondern nur im allgemeinen täglichen 9-Uhr-Sammel-Push.
- Zwei Klärfragen aus dem Issue — Fortschreiben nach Abschluss, sichtbares Uhrzeit-Feld — wurden bewusst nicht umgesetzt.

## Freigabe-Frage

Reicht es, dass nur neu angelegte Wiederholungen automatisch ein Fälligkeitsdatum bekommen, während bestehende ohne manuelles Nachbearbeiten weiter stumm bleiben?
