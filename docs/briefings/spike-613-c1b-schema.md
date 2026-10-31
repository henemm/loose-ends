---
spec_file: docs/specs/spike-613-schnitt-c1b-schema.md
spec_sha256: 170702787888d2b939437c6e4637084f630e6cf2122429311572dac109697d13
spec_frozen_sha256: 2b8af1c5bbae708d9b7e3bc732778c5c9da7e38689b82205b6e11288f6814c26
---

# PO-Briefing: spike-613-c1b-schema

- **Spec:** docs/specs/spike-613-schnitt-c1b-schema.md
- **Issue:** #613
- **Erstellt:** 2026-10-31

## Was gebaut wird

Der Dienst für Claude bekommt seine Datenablage für Aufgabenübersicht, Aufträge und Ergebnisse; in der App ändert sich nichts.

## Definition of Done

Die Servertests und der automatische Lauf auf GitHub sind grün, und die Datenbank weist Rohtexte, Notizen und fehlerhafte Aufträge selbst ab.

## Wie geprüft wird

Tests spielen die Beispiele des Vertrags gegen eine echte Datenbank und prüfen Abweisungen; Dienstlogik, Anmeldung und Betrieb sind nicht Teil davon.

## Kritische Anmerkungen

- Strenge Datenschutzprüfung: Neue Felder in der Übersicht brauchen künftig eine Datenbankänderung, bewusst so gewollt (#625).
- Das Ticket selbst konnte ich nicht lesen; Abgleich lief gegen Analyse und Vertrag.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
