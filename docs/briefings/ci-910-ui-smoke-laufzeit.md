---
spec_file: docs/specs/feat-910-ui-smoke-aufteilung.md
spec_sha256: e54a1f47238d3740266587b7c03d7529adf90700d66013777ec9a1f98594d365
spec_frozen_sha256: 553e43787ef9128824ac91b02ee90e9f6e1db52b61e5192454c3838da163caa5
---

# PO-Briefing: ci-910-ui-smoke-laufzeit

- **Spec:** docs/specs/feat-910-ui-smoke-aufteilung.md
- **Issue:** #910
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die automatische Bedienprüfung läuft auf vier gleichzeitigen Simulatoren statt einem und liefert ihr Ergebnis in etwa 30 Minuten.

## Definition of Done

Alle vier Teile laufen grün, jeder unter 45 Minuten, die Gesamtprüfung unter 60 Minuten, und ein absichtlich roter Teil macht die Sammelprüfung rot.

## Wie geprüft wird

Tests beweisen die lückenlose, stabile Verteilung aller Testklassen; Laufzeit und rote Probe zeigen sich erst im echten Lauf der Prüfung.

## Kritische Anmerkungen

- Das Ticket verlangte den größten Posten zu verkürzen; die Spec verteilt stattdessen die Last, weil keine einzelne Klasse schuld ist.
- Die 30 Minuten sind eine Schätzung; der Beleg steht noch aus.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
