---
spec_file: docs/specs/tooling/fix-341-testlaeufe-verlaesslich.md
spec_sha256: 52f48e973443d0f7ccb38f49449d9a297f485cbd5176e845897c783f74acd2fc
spec_frozen_sha256: a2209eee6aac7be7ee3374eb9a10cab90753b1132e7631b57d1bca6ef5497102
---

# PO-Briefing: fix-341-testlaeufe-verlaesslich

- **Spec:** docs/specs/tooling/fix-341-testlaeufe-verlaesslich.md
- **Issue:** #341
- **Erstellt:** 2026-10-17

## Was gebaut wird

Testläufe werden verlässlich: Unit-Tests laufen nie auf Hennings Mac, parallele Sitzungen stören einander nicht, der Kalendertest ist stabil.

## Definition of Done

Unit-Tests laufen im Simulator, zwei gleichzeitige Sitzungen laufen nacheinander, und die Kalendertests sind fünfmal hintereinander grün.

## Wie geprüft wird

Neun Skripttests belegen Sperre, Bauordner und Simulator-Wahl; Kalender- und UI-Stabilität zeigen nur wiederholte Belegläufe, keine dauerhaften Tests.

## Kritische Anmerkungen

- Warum das Wischen im roten Kalenderlauf ausfiel, bleibt ungeklärt; die Härtung wiederholt nur, Flackern könnte bleiben.
- Umfang liegt an der 250-Zeilen-Grenze; die Sperre könnte als eigenes Ticket abgetrennt werden.
- Alle Sitzungen teilen weiter einen Simulator und warten bis zu 30 Minuten aufeinander.

## Freigabe-Frage

Soll dieser Werkzeug-Umbau, der nichts in der App ändert, in einem Zug umgesetzt werden?
