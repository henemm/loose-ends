---
spec_file: docs/specs/spike-613-schnitt-c1a-server-geruest.md
spec_sha256: 5af5e18ccc60b351c6ea750aede39b92fbaf47cf16a8943a1cb54e2db95ce16f
spec_frozen_sha256: 95df6502378505a9f2a5eef8c4fabfc740604a5ae632ebe2b2965bf7bab465c9
---

# PO-Briefing: spike-613-c1-server-geruest

- **Spec:** docs/specs/spike-613-schnitt-c1a-server-geruest.md
- **Issue:** #613
- **Erstellt:** 2026-10-31

## Was gebaut wird

Ein leeres Gerüst für Hennings eigenen Dienst für Claude, mit Datenbank-Fortschreibung und automatischer Prüfung; in der App ändert sich nichts.

## Definition of Done

Die automatische Prüfkette läuft lokal und auf GitHub grün, Datenbank-Änderungen werden genau einmal angewandt, und die App bleibt unverändert.

## Wie geprüft wird

Tests gegen echte Datenbank belegen Reihenfolge, einmaliges Anwenden, Rückrollen bei Fehlern und Ablehnung falscher Nummern; Datenschema und Anmeldung sind noch nicht enthalten.

## Kritische Anmerkungen

- Ticket verlangte Backend-Wahl und ADR-2 ablösen; stattdessen gilt Hennings Weg B, die Entscheidung wird erst im letzten Schnitt festgehalten.
- Das Datenschema ist in Folgeschnitt C1b ausgelagert; dieser Schnitt liefert noch keine nutzbare Funktion.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
