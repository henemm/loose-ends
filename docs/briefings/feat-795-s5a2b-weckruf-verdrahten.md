---
spec_file: docs/specs/feat-795-schnitt-5a2b-weckruf-verdrahten.md
spec_sha256: 77ecb91f00d9c414f315141fcb41ab7f100381de61bdbcc395b329698866d103
spec_frozen_sha256: 5d917ce6644e2748c0b2a07782450a3720f87aa048847619c607b0f37dda01d0
---

# PO-Briefing: feat-795-s5a2b-weckruf-verdrahten

- **Spec:** docs/specs/feat-795-schnitt-5a2b-weckruf-verdrahten.md
- **Issue:** #795
- **Erstellt:** 2026-11-14

## Was gebaut wird

Neue Aufträge von Claude stupsen die Geräte des Kontos still an; ohne Apple-Schlüssel auf dem Server bleibt das aus.

## Definition of Done

Automatische Serverprüfungen sind grün; ohne Schlüssel verhält sich der Dienst unverändert, mit Test-Attrappe löst ein neuer Auftrag den Anstupser aus.

## Wie geprüft wird

Automatische Tests belegen Anstupsen je Auftragsart, keinen Doppelruf, Fehlertoleranz und Startabbruch; echter Apple-Versand wird nicht geprüft.

## Kritische Anmerkungen

- Der erste echte Apple-Versand folgt erst im nächsten Schnitt; bis dahin ist für dich nichts sichtbar.
- Dateigrenze und Doku-Änderungen werden nur einmalig bei der Abnahme belegt, nicht dauerhaft getestet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
