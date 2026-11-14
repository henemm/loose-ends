---
spec_file: docs/specs/feat-615-schnitt-4f-abnahme.md
spec_sha256: bc3afb904997b5cae06741959897aa22a2baec05055136e359746d18c064cafd
spec_frozen_sha256: 41d72db33d3edd61e46678f4334472a57ec82ebf9ab1d464f993cc2bad883fe6
---

# PO-Briefing: feat-615-s4f-abnahme

- **Spec:** docs/specs/feat-615-schnitt-4f-abnahme.md
- **Issue:** #615
- **Erstellt:** 2026-11-14

## Was gebaut wird

Abmelden und Konto löschen werden im Simulator gegen einen lokalen Dienst nachgewiesen; die Anmeldung folgt per TestFlight.

## Definition of Done

Nach dem Löschen im Simulator sind alle Tabellen des lokalen Dienstes leer, und du meldest dich in TestFlight an, ab und wieder an.

## Wie geprüft wird

Zwei Simulator-Läufe zählen die Datenbankzeilen vorher und nachher; der echte Apple-Widerruf ist nur per Attrappe belegt.

## Kritische Anmerkungen

- Apple-Widerruf wird lokal nur übersprungen und nie echt ausgelöst, wie von dir am 2026-11-14 entschieden.
- Löschen der Claude-Verbindungsdaten belegen nur Server-Tests, nicht der Simulator-Lauf; dort bleibt dieser Wert bei 0.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
