---
spec_file: docs/specs/feat-842-schnitt-4b-1-en-watch.md
spec_sha256: 2b882ed8ed897bc628fffb2871ce63e375329876e2d89db2361bdee467b9f3cc
spec_frozen_sha256: 48aa7d370b347599c4067ce16e26aaa84aa1ea0b74f4e28bf45020f52c180f02
---

# PO-Briefing: feat-842-s4b-en-watch

- **Spec:** docs/specs/feat-842-schnitt-4b-1-en-watch.md
- **Issue:** #842
- **Erstellt:** 2026-11-08

## Was gebaut wird

Zwei englische Apple-Watch-Bilder für die englische Store-Seite entstehen aus der echten Uhr-App, mit erfundenen englischen Beispielaufgaben.

## Definition of Done

Zwei englische Watch-Bilder ohne deutsche Wörter liegen bereit, die deutschen bleiben unverändert, und Henning bestätigt nach dem TestFlight-Bau, dass die Uhr-App normal startet.

## Wie geprüft wird

Skript-Tests prüfen Ablage und Eintrag; die echten Simulator-Läufe liefern die Bilder, die Bildbeschreibung prüft Sprache. Hochladen bei Apple bleibt ungeprüft.

## Kritische Anmerkungen

- Die drei englischen Beispielaufgaben stehen sichtbar im Store und sind von dir noch nicht gesehen.
- Uhr-App wird minimal geändert, deshalb Pflichtprüfung per TestFlight; im Normalbetrieb ändert sich nichts.
- Uhrzeit auf den Bildern ist echte Zeit, nicht einstellbar; Mac (4b-2) und Hochladen (4c) folgen separat.

## Freigabe-Frage

Passen die Beispielaufgaben „Check the tax notice“, „Call Anna about her birthday“ und „Water the flowers“ für die englischen Watch-Bilder?

## Ampel

Ampel: rot
