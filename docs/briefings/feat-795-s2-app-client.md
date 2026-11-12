---
spec_file: docs/specs/feat-795-schnitt-2a-app-client.md
spec_sha256: c5e734daf4bdb2610fa0790b47653b703e96bc72fd1b0c5255a8f106916d9f94
spec_frozen_sha256: a0d6627d7c30106ceef65e420ff595d04a4a2eeabbec5fd14cb566d6fdb45964
---

# PO-Briefing: feat-795-s2-app-client

- **Spec:** docs/specs/feat-795-schnitt-2a-app-client.md
- **Issue:** #795
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die App lernt, ihre Aufgabenliste an den Dienst zu schicken und Claudes Aufträge abzuholen; ausgelöst wird noch nichts.

## Definition of Done

Alle 14 Prüfungen laufen grün, die App startet im Simulator unverändert und sendet weiterhin nichts mehr als bisher.

## Wie geprüft wird

Automatische Tests gegen einen Stellvertreter belegen Aufrufform und Fehlerfälle; der Durchlauf gegen den echten Dienst folgt erst in Schnitt S3.

## Kritische Anmerkungen

- Ticket selbst nicht lesbar; geprüft gegen das Kontext-Dokument. Gerätekennung bewusst in Folgeschnitt S2b verschoben.
- Zusatz: Unlesbare Aufträge werden abgelehnt gemeldet, damit der Dienst sie nicht endlos neu ausgibt. Keine sichtbare Folge.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
