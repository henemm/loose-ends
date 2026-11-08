---
spec_file: docs/specs/feat-615-schnitt-4a-sitzungsablauf.md
spec_sha256: cf84eb6542c77b6ad6236459c15cebc67522f345142bfad5231050c43e673bcd
spec_frozen_sha256: 473df483f22bda7b227687b292a53dcb0226a37a0c90f1dfd716e484b01dff5d
---

# PO-Briefing: feat-615-s4-app-anmeldung

- **Spec:** docs/specs/feat-615-schnitt-4a-sitzungsablauf.md
- **Issue:** #615
- **Erstellt:** 2026-11-08

## Was gebaut wird

Eine Anmeldung am Dienst läuft nach 90 Tagen ohne Nutzung ab; jede Nutzung verlängert sie wieder.

## Definition of Done

Der Dienst lehnt eine 90 Tage unbenutzte Sitzung ab, eine benutzte bleibt gültig, und alle Server-Tests laufen grün.

## Wie geprüft wird

Automatische Tests prüfen Grenze bei 90 Tagen, Verlängerung und Abmelden; die Ablehnung der Löschroute bei abgelaufener Sitzung wird nur abgeleitet, nicht direkt getestet.

## Kritische Anmerkungen

- Von außen ändert sich nichts sichtbar: Die App ruft den Dienst noch nicht auf, es folgen drei weitere Schritte (4b bis 4d).

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
