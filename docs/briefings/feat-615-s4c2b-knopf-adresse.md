---
spec_file: docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
spec_sha256: 6b07fcb7bf8acbfed4da37931035958db3cebb7ccd2eb3ee9167ce550a60c096
spec_frozen_sha256: 7464ac4d67f5e320fd1406bc3c527b7b5bcfbd88ffd04af31612a950fbed79ee
---

# PO-Briefing: feat-615-s4c2b-knopf-adresse

- **Spec:** docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
- **Issue:** #615
- **Erstellt:** 2026-11-10

## Was gebaut wird

Beim Anmelden bleibt der Apple-Knopf grau sichtbar, und die App akzeptiert als Dienst-Adresse nur verschlüsselte Adressen.

## Definition of Done

Im Simulator bleibt der Knopf während der Anmeldung grau mit Fortschrittszeile, fremde unverschlüsselte Adressen werden abgelehnt, alle Tests und Bauten sind grün.

## Wie geprüft wird

Unit- und Simulator-Tests belegen Knopfzustand und Adressregel; ob Apples Anmeldefenster bei grauem Knopf zuverlässig antwortet, zeigt erst die spätere Geräteprobe.

## Kritische Anmerkungen

- Keine — Spec deckt die Anfrage ab, jede Anforderung hat einen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
