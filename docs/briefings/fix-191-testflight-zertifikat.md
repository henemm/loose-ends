---
spec_file: docs/specs/tooling/fix-191-testflight-zertifikat.md
spec_sha256: 362314c53a2e96d8bd4dfd941543e1d318ad41f7520c4e7875fc40754c33b8bd
---

# PO-Briefing: fix-191-testflight-zertifikat

- **Spec:** docs/specs/tooling/fix-191-testflight-zertifikat.md
- **Issue:** #191
- **Erstellt:** 2026-10-03

## Was gebaut wird

Der TestFlight-Lauf räumt seine eigenen Signier-Zertifikate weg und scheitert nicht mehr am Konto-Limit.

## Definition of Done

Zwei TestFlight-Läufe hintereinander laufen grün, die Zertifikatszahl im Konto bleibt gleich, die Anleitung beschreibt den Weg.

## Wie geprüft wird

Skripttests belegen die enge Auswahl gegen einen Fake-Server; ob sie echte Konto-Zertifikate richtig trifft, zeigt nur ein Probelauf.

## Kritische Anmerkungen

- Widerruf ist unumkehrbar; ob "Created via API" Hennings eigene Zertifikate sicher verschont, ist unbelegt, Probelauf entscheidet.
- Ob der Export selbst Zertifikate verbraucht, ist offen; dann bliebe die Zahl nicht gleich.
- Ticket-Alternative dauerhaftes Zertifikat wurde nicht gewählt, nur Rückfall bei schlechtem Probelauf.

## Freigabe-Frage

Darf der Lauf nach vorherigem Probelauf per Schnittstelle Entwicklungs-Zertifikate namens "Created via API" widerrufen?
