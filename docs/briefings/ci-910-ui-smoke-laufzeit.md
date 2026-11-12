---
spec_file: docs/specs/feat-910-ui-smoke-aufteilung.md
spec_sha256: 063a32b0aeaea24fa6277fba4d467290988437a778984aee98fb73352b1d184a
spec_frozen_sha256: 52aff86eabd3e0679c4368f7bca012bb0227fc15549e0df32cbe8c3fb901ef50
---

# PO-Briefing: ci-910-ui-smoke-laufzeit

- **Spec:** docs/specs/feat-910-ui-smoke-aufteilung.md
- **Issue:** #910
- **Erstellt:** 2026-11-12

## Was gebaut wird

Die automatische Bedienprüfung läuft auf vier Simulatoren gleichzeitig, statt fast zwei Stunden nacheinander.

## Definition of Done

Ein echter Prüflauf zeigt alle vier Teile grün, jeden unter 45 Minuten, die Gesamtprüfung unter 60 Minuten.

## Wie geprüft wird

Tests belegen die lückenlose Verteilung aller Testklassen; ein echter Lauf und eine absichtlich rote Probe belegen Zeit und Rot-Verhalten.

## Kritische Anmerkungen

- Die Sammelprüfung steht im Schutz vor dem Zusammenführen; ein Fehler dort könnte rote Teile durchlassen, deshalb die rote Probe.
- Die geschätzten 30 Minuten sind unbelegt; acht gleichzeitige Rechner liefen bisher ohne Warteschlange, zwölf sind ungetestet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
