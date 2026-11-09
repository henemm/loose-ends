---
spec_file: docs/specs/feat-615-schnitt-4b3-schluesselbund.md
spec_sha256: 607c51876057033c012ef12bd4b987b8bf86b28409675b67eee4a7d6addc99d1
spec_frozen_sha256: 8734ff443688ed9b029c3ad8e8d8d1da52fe6f59b6e9f140941874fe30592918
---

# PO-Briefing: feat-615-s4b3-schluesselbund

- **Spec:** docs/specs/feat-615-schnitt-4b3-schluesselbund.md
- **Issue:** #615
- **Erstellt:** 2026-11-09

## Was gebaut wird

Die App bekommt intern einen sicheren Speicher für die Anmeldung beim Claude-Dienst; sichtbar ist dafür noch nichts.

## Definition of Done

Alle neuen Tests und der gesamte Testlauf sind grün, die App baut fehlerfrei, und im Produkt ändert sich nichts Sichtbares.

## Wie geprüft wird

Tests mit einem Attrappen-Speicher belegen Ablauf und Fehlerfälle; der echte Schlüsselbund des Systems wird erst im Folgeschnitt geprüft.

## Kritische Anmerkungen

- Echter Schlüsselbund bleibt bis zum Folgeschnitt ungeprüft; ob das System die Abfragen annimmt, zeigt sich erst dort (dokumentiert, nichts ruft ihn auf).
- Kleine Verhaltensänderung: Vom System selbst abgebrochene Anfragen gelten still als Abbruch statt als „später erneut“; praktisch kaum auslösbar.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
