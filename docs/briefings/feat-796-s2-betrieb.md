---
spec_file: docs/specs/feat-796-schnitt-2-image-und-sperre.md
spec_sha256: 6b920b41e849fac3b0a72e6b57bc141ab342d2590356ff5a4819a91f1a2d601d
spec_frozen_sha256: da173ea51d55f699f216fb2c69fd2f7691ef924cb15e4b302132bd2c11fa109b
---

# PO-Briefing: feat-796-s2-betrieb

- **Spec:** docs/specs/feat-796-schnitt-2-image-und-sperre.md
- **Issue:** #796
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst wird als startfähiges Paket verpackt, und gleichzeitiger Start zweier Instanzen richtet die Datenbank nicht mehr doppelt ein.

## Definition of Done

Ein automatischer Testlauf startet das Paket gegen Postgres 18, die Gesundheitsabfrage meldet "ok", Beenden endet sauber, und parallele Starts bleiben fehlerfrei.

## Wie geprüft wird

Automatische Tests gegen echte Datenbank und ein CI-Containerlauf belegen das; lokal gibt es kein Docker, Betrieb auf dem Server wird nicht getestet.

## Kritische Anmerkungen

- Ticketziel (läuft auf Hetzner, Sicherung, Überwachung) folgt erst im Schnitt S4; hier entsteht nichts auf dem Server.
- Der Paket-Nachweis läuft nur in der CI, nicht lokal; das Ticket bleibt offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
