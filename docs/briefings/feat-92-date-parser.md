---
spec_file: docs/specs/measurement/feat-92-date-parser.md
spec_sha256: f1027ddfcc15b5fe3cea234074cd59b814c7fa2c775843ce8da7a7ccf2c39d6a
---

# PO-Briefing: feat-92-date-parser

- **Spec:** docs/specs/measurement/feat-92-date-parser.md
- **Issue:** #92
- **Erstellt:** 2026-09-20

## Was gebaut wird

Ein Mess-Nachweis, ob ein Regel-Erkenner das Modell beim Datum ersetzen kann — noch keine Änderung an der App.

## Definition of Done

Ein Bericht zeigt, dass der Regel-Erkenner mindestens 95 Prozent der Zeitangaben trifft und nie ein Datum erfindet.

## Wie geprüft wird

Automatisierte Tests rechnen den Erkenner gegen 317 Beispielsätze; geprüft wird nur am Computer, nicht in der laufenden App.

## Kritische Anmerkungen

- Vier der sechs Ticket-Anforderungen — App-Umbau, iPhone-Nachweis, Eintrag in Ticket #67 — folgen erst später.
- Nach dieser Lieferung setzt weiterhin das Modell das Datum — für Nutzer ändert sich nichts.
- Fünf offene Fragen zur genauen Datumswahl (z. B. Tag bei „am Wochenende") werden erst später entschieden.

## Freigabe-Frage

Reicht dir dieser Mess-Nachweis als Zwischenschritt, obwohl die App das Datum weiterhin vom Modell setzen lässt?
