---
spec_file: docs/specs/measurement/spike-24-mail-ruecksprung.md
spec_sha256: 55754c3e6372306e65b6601fd8415d8e33f87f66f8e2442a291c59034b2649a1
---

# PO-Briefing: spike-24-mail-ruecksprung

- **Spec:** docs/specs/measurement/spike-24-mail-ruecksprung.md
- **Issue:** #24
- **Erstellt:** 2026-10-08

## Was gebaut wird

Messen, ob Apple Mail beim Teilen einen Rücksprung-Link zur Quell-Mail liefert, und einen Ersatzweg festlegen.

## Definition of Done

Ein Bericht belegt je Konto und Weg, ob der Rücksprung die richtige Mail öffnet; der Ersatzweg ist dokumentiert.

## Wie geprüft wird

Tests belegen nur das Protokollieren; das eigentliche Ergebnis stammt aus deinem Handtest mit vier Mails auf dem iPhone.

## Kritische Anmerkungen

- Kein Schwellenwert für „zuverlässig"; die Gerätemessung hat keinen automatisierten Test, das Urteil bleibt Ermessen.
- Messung läuft erst nach deinem wörtlichen „jetzt ist ein Test möglich"; bis dahin bleibt der Spike offen.
- Zusatz: Beschriftung „Open in Mail" ist im Ticket nicht verlangt; nur bei bestätigtem Ergebnis.

## Freigabe-Frage

Freigeben, inklusive eines späteren etwa 15-minütigen Gerätetests mit vier Mails aus zwei Konten?
