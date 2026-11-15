---
spec_file: docs/specs/feat-622-schnitt-2-claude-sichtbar.md
spec_sha256: 693e549e04b12c48e51ba7aca20c52dd92894ec133ca8775a07a7454fdc89470
spec_frozen_sha256: 408e9ff4c69ba651c4775a91b5eb78e4872feea43189802f5bdba510d1ecd495
---

# PO-Briefing: feat-622-s2-claude-sichtbar

- **Spec:** docs/specs/feat-622-schnitt-2-claude-sichtbar.md
- **Issue:** #622
- **Erstellt:** 2026-11-15

## Was gebaut wird

Im Aufgabendetail steht „Zuletzt von Claude · heute 14:02“, und die Änderungsliste nennt Claude als Urheber.

## Definition of Done

Eine von Claude geänderte Aufgabe zeigt die Zeile samt Zeit, die Liste nennt „Claude“ ohne Zurücksetzen-Knopf, Screenshots hell und dunkel liegen vor.

## Wie geprüft wird

Tests belegen Erkennung, Zeile und Liste mit einem echten Claude-Auftrag im Simulator; Gestern- und Älter-Anzeige sind ungetestet, Gerät entfällt.

## Kritische Anmerkungen

- Von Claude neu erfasste Aufgaben bekommen keine Zeile, weil dabei keine Änderung entsteht (bewusst ausgeklammert).
- Der Nachweis aus claude.ai fehlt noch; das Ticket bleibt offen, bis Claude ihn nach der Anmeldung nachholt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
