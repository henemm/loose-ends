---
spec_file: docs/specs/enrichment/feat-95-parser-in-app.md
spec_sha256: ef39252af0df8f0e6182422aa9ef4a25ffbd5c4ec1d82a7fae1e74298d3e432d
---

# PO-Briefing: feat-95-parser-in-app

- **Spec:** docs/specs/enrichment/feat-95-parser-in-app.md
- **Issue:** #95
- **Erstellt:** 2026-09-21

## Was gebaut wird

Die App erkennt Termine (Datum und Uhrzeit) künftig selbst aus dem Text statt vom Sprachmodell geschätzt.

## Definition of Done

Erkannte Termine sind zuverlässiger, erscheinen auch ohne Apple Intelligence, „nächsten Freitag" meint nun die Folgewoche.

## Wie geprüft wird

Automatisierte Tests prüfen jede Ausdrucksart, den Modellausfall-Fall und die Folgewochen-Regel; tatsächliches Nutzerverhalten prüfen sie nicht.

## Kritische Anmerkungen

- Reine Uhrzeitangaben ohne erkanntes Datum (z. B. „jeden Tag um 7 Uhr") werden weiterhin nicht gespeichert — ausgeklammert als Folgeaufgabe.
- Regel-Termine und Modell-Termine sehen für den Nutzer identisch aus — Unterscheidung ist eine spätere Aufgabe.
- Termine werden künftig auch ganz ohne Apple-Intelligence-Zugriff gesetzt — im Ticket nicht gefordert, aber im Sinne der Projektregel.

## Freigabe-Frage

Ist vertretbar, dass ein Regel-Termin optisch wie ein Modell-Termin aussieht und dass reine Uhrzeitangaben ohne Datum vorerst verloren gehen?
