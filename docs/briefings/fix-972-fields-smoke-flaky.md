---
spec_file: docs/specs/fix-972-fields-smoke-flaky.md
spec_sha256: 41fcb724fecf2d0aa0a2a253bc7b19dff31128f76afbb247d802b9a3c7c5f725
spec_frozen_sha256: 5f15190c79482857295ba65983ca68096e11183e1d2257982d068a8fbfd8e826
---

# PO-Briefing: fix-972-fields-smoke-flaky

- **Spec:** docs/specs/fix-972-fields-smoke-flaky.md
- **Issue:** #972
- **Erstellt:** 2026-11-21

## Was gebaut wird

Zwei automatische Prüfungen warten geduldiger und rechnen mit dem Tageswechsel, damit sie in der Testumgebung nicht mehr zufällig scheitern.

## Definition of Done

Die Prüfung läuft im Simulator zehnmal hintereinander grün, und die nächsten fünf Testläufe auf dem Hauptstand bleiben ohne Fehlschlag.

## Wie geprüft wird

Zehn Simulator-Läufe belegen Stabilität; der Mitternachtsfall selbst lässt sich nicht nachstellen und wird nur durch die Logik abgedeckt.

## Kritische Anmerkungen

- Zusatz: Ein zweiter wackliger Test (Mitternachtswechsel) wird mitrepariert, im Ticket nicht verlangt; die Ursache im Ticket war eine andere als vermutet.
- Die App selbst war nie fehlerhaft; geändert wird nur Testcode, keine App-Funktion.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
