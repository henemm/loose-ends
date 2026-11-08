---
spec_file: docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md
spec_sha256: 182523449e58adb5da679e63016ac3501712c3fee1f16156892ddd2b7f10d16f
spec_frozen_sha256: 6486da08af639b5466229fd5c9243064063adbb07223ccff919246951dbc9d82
---

# PO-Briefing: feat-842-s4c-en-hochladen

- **Spec:** docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md
- **Issue:** #842
- **Erstellt:** 2026-11-08

## Was gebaut wird

Ein Werkzeug lädt die elf englischen Store-Bilder bei Apple hoch, ohne sie auf der Store-Seite sichtbar zu machen.

## Definition of Done

Alle elf englischen Bilder liegen bei Apple bereit, ein zweiter Lauf legt nichts doppelt an, Deutsch und die Store-Seite bleiben unverändert.

## Wie geprüft wird

Automatische Tests ohne Apple-Zugang und echte Läufe bei Apple belegen Upload und Wiederholbarkeit; dass die Bilder auf der Store-Seite erscheinen, prüft erst der Folgeschnitt.

## Kritische Anmerkungen

- Ticketziel (englische Bilder auf der Store-Seite) ist erst nach dem Folgeschnitt erreicht; bis dahin bleibt die Einreichung von 1.0.1 blockiert.
- Mac-Bilder werden übersprungen, weil keine bearbeitbare Mac-Version existiert; das Ticket bleibt dafür offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
