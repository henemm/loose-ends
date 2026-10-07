---
spec_file: docs/specs/feat-226-schnitt-2a-uebergabe.md
spec_sha256: ccacfcc340d65b6617ff7d3b5e755f8446b8cb630c4513803fce6271774a4adb
---

# PO-Briefing: feat-226-zustellung

- **Spec:** docs/specs/feat-226-schnitt-2a-uebergabe.md
- **Issue:** #226
- **Erstellt:** 2026-10-07

## Was gebaut wird

Die App merkt sich je Gerät übergebene Ortserinnerungen, damit keine Aufgabe doppelt erinnert.

## Definition of Done

Neue Tests zu allen Planungsregeln und alle bisherigen Tests sind grün; in der App ändert sich nichts Sichtbares.

## Wie geprüft wird

Tests belegen die Planungsregeln mit echten Aufgaben; ob das System wirklich erinnert, zeigt erst Schnitt 2b.

## Kritische Anmerkungen

- Widerspruch: Entwurf #242 braucht einen Zustellvermerk an der Aufgabe, den das System laut Recherche nicht meldet.
- Annahme „nicht mehr offen heißt ausgelöst“ ist unbelegt; verliert das System eine Anfrage, bleibt die Aufgabe stumm.
- Ticket-Ziel „auf dem Gerät nachgewiesen“ bleibt offen; Nutzen entsteht erst mit Schnitt 2b.

## Freigabe-Frage

Gibst du den unsichtbaren Schnitt 2a frei, obwohl Entwurf #242 danach neu geschrieben werden muss?
