---
spec_file: docs/specs/tooling/fix-578-ui-test-kaltstart.md
spec_sha256: 664f091d6d82c8e06bd6cea0a3ea90f795d3d54851ea7035c9b64a5d144848da
spec_frozen_sha256: beeea8e425a987deff5a593f158898ccb4660792360ce9a12b5d2d4d50a10c05
---

# PO-Briefing: fix-578-ui-test-kaltstart

- **Spec:** docs/specs/tooling/fix-578-ui-test-kaltstart.md
- **Issue:** #578
- **Erstellt:** 2026-10-21

## Was gebaut wird

Der Kalender-UI-Test läuft in der CI auch als erster Test nach frischem Simulatorstart zuverlässig grün.

## Definition of Done

Fünf reguläre CI-Läufe sind beim ersten Versuch grün, dazu ein sechster Lauf, in dem nur der Kalender-Test zuerst läuft.

## Wie geprüft wird

Skripttests sichern die Simulator-Vorbereitung; ob der Fehler wirklich weg ist, zeigen nur die CI-Läufe, lokal war er nie auslösbar.

## Kritische Anmerkungen

- Abweichung: Der Kalender-Systemdialog wird in der CI nicht mehr durchgespielt, die Berechtigung wird vorab erteilt.
- Ungeprüft: Überlebt die vorab erteilte Berechtigung die App-Installation? Sonst ist die Spec widerlegt und wird neu geschrieben.

## Freigabe-Frage

Akzeptierst du, dass der Kalender-Dialog in der CI künftig nicht mehr getestet wird?
