---
spec_file: docs/specs/measurement/feat-88-b1b-export.md
spec_sha256: ef5a89968081160ebf73bedd4d2067ce3d49d30a4b30b923b94c822a8b9c8751
spec_frozen_sha256: 9694fc03a3b9f372b6e54df569246bbf780cfec813a1d4e85efe69a189e45f3b
---

# PO-Briefing: feat-88-b1b-export

- **Spec:** docs/specs/measurement/feat-88-b1b-export.md
- **Issue:** #88 (Schnitt B1b)
- **Erstellt:** 2026-10-29

## Was gebaut wird

Ein Werkzeug schreibt Hennings Rohsätze und Korrekturen aus dem Speicher der Mac-App in die Messdatei.

## Definition of Done

Auf einem Wegwerf-Speicher entsteht eine ladbare Rohsatz-Datei, alle Tests sind grün, und Hennings echter Speicher bleibt unberührt.

## Wie geprüft wird

Tests bauen einen Kunst-Speicher und laden die Ausgabe mit dem echten Leser; ob Hennings echter Speicher gleich aufgebaut ist, zeigt erst B2.

## Kritische Anmerkungen

- Abweichung vom Ticket: fünf statt drei Dateien, rund 230 statt 180 Zeilen, weil Tests im Simulator kein Skript starten können.
- Das Skript selbst (Argumente, Standardpfad) prüft nur ein Handlauf auf dem Wegwerf-Speicher, kein automatischer Test.

## Freigabe-Frage

Gibst du den Export mit fünf Dateien frei, wobei der Lauf auf Hennings echtem Speicher erst später in B2 folgt?

## Ampel

Ampel: rot
