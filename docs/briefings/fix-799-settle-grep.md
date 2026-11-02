---
spec_file: docs/specs/tooling/fix-799-settle-grep.md
spec_sha256: 7ebf330a9f1089b8b8a869f068489a4dd0a6d073246c3ad9f6917357f364639b
spec_frozen_sha256: 2213569cda53b2c56486d70aec0ba31b82bc2ed6fcc33ceccba4b20ad0462a67
---

# PO-Briefing: fix-799-settle-grep

- **Spec:** docs/specs/tooling/fix-799-settle-grep.md
- **Issue:** #799
- **Erstellt:** 2026-11-02

## Was gebaut wird

Der CI-Schritt „Simulator beruhigen“ bricht nicht mehr ab, wenn kein Poster-Prozess läuft.

## Definition of Done

Der Prüflauf der CI besteht diesen Schritt in allen Sprachen, und beide Kopien des Schritts sind gleich abgesichert.

## Wie geprüft wird

Ein Skripttest vergleicht beide Kopien und spielt den Fall ohne Prozess nach; ob die echte CI grün läuft, zeigt erst der PR-Lauf.

## Kritische Anmerkungen

- Keine — Spec deckt die Anfrage ab, jede Anforderung hat einen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
