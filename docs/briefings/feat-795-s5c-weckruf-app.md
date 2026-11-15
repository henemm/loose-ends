---
spec_file: docs/specs/feat-795-schnitt-5c1-weckruf-kern.md
spec_sha256: fa5ca4d80380f922fce37356eb5209392dbb84004ca515246f68c0da32953848
spec_frozen_sha256: 0c20085ae8042d8a9552da37ddcf028caf8ea68b4121e839f962698de5ecd105
---

# PO-Briefing: feat-795-s5c-weckruf-app

- **Spec:** docs/specs/feat-795-schnitt-5c1-weckruf-kern.md
- **Issue:** #795
- **Erstellt:** 2026-11-15

## Was gebaut wird

Die App bekommt Bausteine, um sich beim Dienst für den stillen Weckruf anzumelden und danach Claudes Aufträge sofort abzuholen.

## Definition of Done

Alle neuen Tests und die gesamte bisherige Testsuite sind grün, die App baut, und für dich ändert sich nichts Sichtbares.

## Wie geprüft wird

Automatische Tests gegen Attrappen belegen Anmeldung und Abholreihenfolge; ob ein echtes Gerät den Weckruf erhält, belegt erst der Folgeschnitt.

## Kritische Anmerkungen

- Umfang etwa 420 statt 250 Zeilen, wegen Sicherheitstests; die Spec macht die Annahme zur Freigabe (Präzedenz: früherer Überhang akzeptiert).
- Nichts ruft die Bausteine auf; der Weckruf wirkt erst mit den Folgeschnitten, die vor der Auslieferung die richtige Umgebung festlegen müssen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
