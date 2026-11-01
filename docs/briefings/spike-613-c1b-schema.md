---
spec_file: docs/specs/spike-613-schnitt-c1b-schema.md
spec_sha256: 0b9e898c72ac67b6456332e2b5bcbf9f2e64699b79cb633ff27b09119715edcf
spec_frozen_sha256: 55527edbd502ead41f2bc6edeea05455b4aa2e3ee5431a7993ab81e9746bd013
---

# PO-Briefing: spike-613-c1b-schema

- **Spec:** docs/specs/spike-613-schnitt-c1b-schema.md
- **Issue:** #613
- **Erstellt:** 2026-11-01

## Was gebaut wird

Der Dienst für Claude bekommt seine Datenablage für Aufgabenübersicht, Aufträge und Ergebnisse; in der App ändert sich nichts.

## Definition of Done

Servertests und GitHub-Lauf sind grün, und die Datenbank weist Rohtexte, Notizen, Aufträge ohne Art und Ergebnisse ohne Ausgang selbst ab.

## Wie geprüft wird

Tests spielen die Vertragsbeispiele gegen eine echte Datenbank und prüfen jede Abweisung; Dienstlogik, Anmeldung und Betrieb sind nicht Teil davon.

## Kritische Anmerkungen

- Neu gegenüber der freigegebenen Fassung: Die Datenbank weist jetzt auch Aufträge ohne Art, Ergebnisse ohne Ausgang und Abschriften ohne Zeitzone ab.
- Strenge Datenschutzprüfung: Neue Felder in der Übersicht brauchen künftig eine Datenbankänderung, bewusst gewollt (#625).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
