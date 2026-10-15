---
spec_file: docs/specs/intents/feat-25-s2a-schema-entitaeten.md
spec_sha256: ea0f25dc4d6c7d3ec7f4820790ff22e493a16cfaeec066c38aaa4957313d0a90
spec_frozen_sha256: 7ab07bbf963c56829e939f9c31f2009cd7ff978100fc534a7116f9438953d156
---

# PO-Briefing: feat-25-s2-siri-intent

- **Spec:** docs/specs/intents/feat-25-s2a-schema-entitaeten.md
- **Issue:** #25
- **Erstellt:** 2026-10-15

## Was gebaut wird

Vorbereitung für Siri-Erinnerungen: Die App versteht künftig Siris Angaben (Liste, Datum, Ort), Siri selbst bemerkt noch nichts.

## Definition of Done

Alle neuen Tests grün, App baut und startet im Simulator unverändert; Nutzer und Siri sehen nichts Neues.

## Wie geprüft wird

Tests belegen Umwandlung von Datum, Ort, Liste und Speichern; ob Siri sie tatsächlich nutzt, zeigt erst der Folgeschnitt.

## Kritische Anmerkungen

- Unvollständiges Datum wird still verworfen: Aufgabe entsteht ohne Fälligkeit, Siri meldet nichts.
- Zeitzonen-Risiko benannt, aber kein Test im Plan; Bau- und Unverändert-Kriterien (AC-9, AC-10) prüft nur der Diff.
- Siri kann das Schema ohne Apple Intelligence ablehnen; Nutzen entsteht erst im Folgeschnitt.

## Freigabe-Frage

Gibst du diesen unsichtbaren Vorbereitungsschnitt frei, einschließlich der Regel, unvollständige Siri-Datumsangaben ohne Fehlermeldung zu ignorieren?
