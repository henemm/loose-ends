---
spec_file: docs/specs/feat-795-schnitt-3a-claude-sync.md
spec_sha256: 7b079df582c166260ff744733fbeea6b7a6585eca22955f4d4c8589024e3ed00
spec_frozen_sha256: a2c1b420cadf329458691a8af35b614b2d4a3d98c05e5edf977ca41f88ee38c9
---

# PO-Briefing: feat-795-s3-claude-sync

- **Spec:** docs/specs/feat-795-schnitt-3a-claude-sync.md
- **Issue:** #795
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die App lernt, ihre Aufgabenliste an Claude zu melden und Aufträge auszuführen, wird aber noch nirgends ausgelöst.

## Definition of Done

Alle neuen und bestehenden Prüfungen laufen grün, die App startet unverändert, und kein anderer Programmteil ruft den Ablauf auf.

## Wie geprüft wird

Automatische Tests mit Attrappe statt echtem Dienst belegen jeden Fehlerfall; der echte Dienst und das Zusammenspiel zweier Geräte folgen erst im nächsten Schnitt.

## Kritische Anmerkungen

- Umfang rund 570 statt 250 Zeilen, fast nur Tests (Code etwa 130); die Annahme steht noch aus.
- Der Zwei-Geräte-Nachweis des Tickets fehlt hier; das Ticket bleibt offen.

## Freigabe-Frage

Darf dieser Schnitt mit rund 570 statt 250 Zeilen gebaut werden, weil der Mehrumfang fast nur aus Tests besteht?

## Ampel

Ampel: rot
