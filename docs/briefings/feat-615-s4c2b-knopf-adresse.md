---
spec_file: docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
spec_sha256: 4182e3d2c0563afe979599b1b3668ae6cf1d15ec29d76dd976a0e34c6b143e2a
spec_frozen_sha256: 8eadd8266b8e49d040d74d52a93a03775b051fcb02f6310d011a6f7db3cfb827
---

# PO-Briefing: feat-615-s4c2b-knopf-adresse

- **Spec:** docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
- **Issue:** #615
- **Erstellt:** 2026-11-10

## Was gebaut wird

Beim Anmelden bleibt der Apple-Knopf grau sichtbar, und der Dienst wird nur noch über verschlüsselte Adresse angesprochen.

## Definition of Done

Während der Anmeldung steht der Knopf grau und nicht antippbar mit Fortschrittszeile; unverschlüsselte fremde Adressen werden abgelehnt; alle bisherigen Tests bleiben grün.

## Wie geprüft wird

Automatische Tests und ein Simulator-Lauf belegen Knopfzustand und Adressregel; ob Apples echtes Anmeldefenster damit zuverlässig antwortet, belegt erst die spätere Geräteprobe.

## Kritische Anmerkungen

- Apples echte Antwort bei deaktiviertem Knopf ist nur auf dem Gerät belegbar; Spec benennt das und verschiebt es auf Schnitt 4d.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
