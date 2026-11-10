---
spec_file: docs/specs/fix-883-mac-widget-nachziehen.md
spec_sha256: fc6ff1f8d382044dd9c46b6ac9880046995920f334f90c640266a92cc00f089c
spec_frozen_sha256: ec344223256d802d8aa895a3716063ed5861d795d282dfae8eae62f413800182
---

# PO-Briefing: fix-883-mac-widget-nachziehen

- **Spec:** docs/specs/fix-883-mac-widget-nachziehen.md
- **Issue:** #883
- **Erstellt:** 2026-11-10

## Was gebaut wird

Das Widget „Als nächstes“ aktualisiert sich auch bei geschlossenem App-Fenster und nach Änderungen von einem anderen Gerät.

## Definition of Done

Bei geschlossenem Mac-Fenster erledigst du am iPhone eine Aufgabe, und das Mac-Widget zeigt binnen weniger Minuten den neuen Stand.

## Wie geprüft wird

Automatische Tests belegen, dass Speichern und Import das Neuladen auslösen; ob das Mac-Widget wirklich aktuell wird, zeigt nur dein Test.

## Kritische Anmerkungen

- Ursache auf dem Mac nicht nachgestellt; bleibt das Widget alt, folgt ein zweiter Schnitt.
- Ticket bleibt bis deiner Rückmeldung offen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
