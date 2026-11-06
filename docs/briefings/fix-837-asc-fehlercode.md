---
spec_file: docs/specs/fix-837-asc-fehlercode.md
spec_sha256: 218f8a413a69ceb911541250f8298e65740392e02818213a9f6889985e43691d
spec_frozen_sha256: ec81cef5909eed76350c43e1531a3784e804da986aedc5fd6cb5ea7e03205817
---

# PO-Briefing: fix-837-asc-fehlercode

- **Spec:** docs/specs/fix-837-asc-fehlercode.md
- **Issue:** #837
- **Erstellt:** 2026-11-06

## Was gebaut wird

Das Werkzeug zum Setzen des Store-Untertitels nennt künftig Apples Fehlercode, wenn Apple eine Änderung ablehnt.

## Definition of Done

Der erneute Untertitel-Lauf nennt im Protokoll Apples Fehlercode zum Fehler 409 oder gelingt, und die Ursache ist benannt.

## Wie geprüft wird

Tests mit Apple-Nachbau belegen Code in der Meldung und keine Nutzertexte; Apples echte Antwort zeigt erst der Lauf nach Merge.

## Kritische Anmerkungen

- Das behebt den 409 nicht, es klärt nur die Ursache; der englische Untertitel bleibt bis dahin ungesetzt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
