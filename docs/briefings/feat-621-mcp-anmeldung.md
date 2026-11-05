---
spec_file: docs/specs/feat-621-schnitt-1-ressourcenseite.md
spec_sha256: 244250f452990e319890350b8d5845ac5ce0b4c05a82bc7d90c0cd1935695eb3
spec_frozen_sha256: 6bd6b1c7a7b1b847e49dfbf8fe15dd257650e868954c851ebd15aedb7990b244
---

# PO-Briefing: feat-621-mcp-anmeldung

- **Spec:** docs/specs/feat-621-schnitt-1-ressourcenseite.md
- **Issue:** #621
- **Erstellt:** 2026-11-05

## Was gebaut wird

Der Dienst für Claude antwortet ohne Anmeldung mit „bitte anmelden“ samt Hinweis, wo; öffentlich bleibt er geschlossen.

## Definition of Done

Ohne Anmeldung kommt „bitte anmelden“ mit Hinweisdokument, jedes Token wird vorerst abgelehnt, und alle Dienst-Tests laufen grün.

## Wie geprüft wird

Automatische Tests gegen eine Wegwerf-Datenbank belegen Antworten und Kontotrennung; Verbinden mit claude.ai und echte Anmeldung werden nicht geprüft.

## Kritische Anmerkungen

- Ticket-Ziel (in claude.ai verbunden, vier Ansichten) ist mit diesem Schnitt nicht erreicht; es folgen mindestens sechs weitere.
- Gesamtumfang etwa 400 Zeilen, über dem Limit; nur der Code (etwa 100) liegt darunter.
- Wahl des Anmeldedienstes fällt erst im dritten Schnitt; heute nimmt das System niemanden herein.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
