---
spec_file: docs/specs/feat-615-schnitt-4c1-konto-gruppe.md
spec_sha256: 50662667f73b2a8d766c62a60fc11740c2e3f4b3029ff7ee0024f1abcac86ec5
spec_frozen_sha256: 16aa110ac123f4614afb05dbffa9b1ccb6d3ae8d7e5b7e9362a12847511e9286
---

# PO-Briefing: feat-615-s4c-konto

- **Spec:** docs/specs/feat-615-schnitt-4c1-konto-gruppe.md
- **Issue:** #615
- **Erstellt:** 2026-11-09

## Was gebaut wird

In den Einstellungen entsteht eine Gruppe „Claude“ zum Anmelden mit Apple, Abmelden und Konto löschen, vorerst in echten Apps verborgen.

## Definition of Done

Im Simulator lassen sich Anmelden, Abmelden und Löschen mit Rückfrage durchspielen, auch beide Fehlerfälle; in der normalen App ist nichts sichtbar.

## Wie geprüft wird

Automatische Tests gegen einen Ersatz-Dienst belegen Zustände, Texte und Schalter; der echte Apple-Dialog und der echte Schlüsselbund bleiben ungeprüft.

## Kritische Anmerkungen

- Umfang überschritten: sieben Dateien, rund 410 Zeilen statt 4–5 Dateien, ±250; Spec bittet um Bestätigung.
- Die Zeile „Konto wird gelöscht …“ stammt nicht aus dem freigegebenen Entwurf.
- Mac-Reihenfolge ohne UI-Test; Dateigrenze und Doku nur einmalig in der Validierung geprüft.

## Freigabe-Frage

Darf der Schnitt mit sieben Dateien und rund 410 Zeilen ungeteilt gebaut werden?

## Ampel

Ampel: rot
