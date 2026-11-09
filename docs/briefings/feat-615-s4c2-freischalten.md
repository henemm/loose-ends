---
spec_file: docs/specs/feat-615-schnitt-4c2a-freischalten.md
spec_sha256: 0431d96dca91cf21aaf024cce09a0d079894a2ddd90e0a53e4bc6d638958554f
spec_frozen_sha256: 0a6346197df5849857d94d19f6d92059fbccc409777ca0a61f34bd84a49d0cfe
---

# PO-Briefing: feat-615-s4c2-freischalten

- **Spec:** docs/specs/feat-615-schnitt-4c2a-freischalten.md
- **Issue:** #615
- **Erstellt:** 2026-11-09

## Was gebaut wird

Konto-Bauten lassen sich per TestFlight-Schalter einschalten und werden nie versehentlich einer App-Store-Version zugeordnet.

## Definition of Done

Die normale TestFlight-App startet wie bisher ohne Gruppe „Claude“; Konto-Bauten sind gekennzeichnet und werden nie dem Store zugeordnet.

## Wie geprüft wird

Automatische Tests im Nachbau belegen Schalter, Kennzeichnung und Sperre; Apples echtes Verhalten zeigt sich erst im ersten TestFlight-Lauf.

## Kritische Anmerkungen

- Umfang knapp über der Grenze (rund 265 statt 250 Zeilen, mehr als fünf Dateien); die Spec verlangt deine ausdrückliche Bestätigung.
- Die Sperre liest eine Textmarke, die jemand in App Store Connect von Hand überschreiben könnte.

## Freigabe-Frage

Nimmst du den leicht überschrittenen Umfang an (265 statt 250 Zeilen), oder soll der Schnitt in zwei Teile geteilt werden?

## Ampel

Ampel: rot
