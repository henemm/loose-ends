---
spec_file: docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md
spec_sha256: 6d0de33cb78b5108468446c0fb9c74e4d8119a863a332b0d20f9f2333684aa16
spec_frozen_sha256: 5a3889829a48e9d192ce093ba592b2004bd3e8e050ffa706f0881ac2e1b386a0
---

# PO-Briefing: feat-842-s4c-en-hochladen

- **Spec:** docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md
- **Issue:** #842
- **Erstellt:** 2026-11-08

## Was gebaut wird

Ein Werkzeug lädt die zwölf englischen Store-Bilder bei Apple hoch, ohne sie auf der Store-Seite sichtbar zu machen.

## Definition of Done

Alle zwölf englischen Bilder liegen bei Apple bereit, ein zweiter Lauf legt nichts doppelt an, Deutsch und die Store-Seite bleiben unverändert.

## Wie geprüft wird

Automatische Tests ohne Apple-Zugang und echte Läufe bei Apple belegen Upload und Wiederholbarkeit; dass die Bilder auf der Store-Seite erscheinen, prüft erst der Folgeschnitt.

## Kritische Anmerkungen

- Ticketziel (englische Bilder auf der Store-Seite) ist erst nach dem Folgeschnitt erreicht; bis dahin bleibt die Einreichung von 1.0.1 blockiert.
- Mac-Bilder werden übersprungen, weil keine bearbeitbare Mac-Version existiert; das Ticket bleibt dafür offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
