---
spec_file: docs/specs/feat-893-schnitt-d-datenschutz.md
spec_sha256: 27ab8e5a33fc146787667b7678dcfac6ea979b79ad80f297df3dddef56d85df7
spec_frozen_sha256: d22bad6fc9eeade61fb6ac560d62011f33f7a7ed82667f8dcd1994c8bdf4a1f1
---

# PO-Briefing: feat-893-d-datenschutz

- **Spec:** docs/specs/feat-893-schnitt-d-datenschutz.md
- **Issue:** #893
- **Erstellt:** 2026-11-10

## Was gebaut wird

Das Einreichwerkzeug zeigt und setzt die Datenschutz-Adresse je Sprache im App Store, damit Version 1.0.1 einreichbar wird.

## Definition of Done

Ein echter Lesedurchlauf belegt das fehlende Feld, die Adresse steht danach bei Apple, und der erneute Einreichversuch von 1.0.1 ist belegt.

## Wie geprüft wird

Skripttests mit nachgebauter Apple-Schnittstelle prüfen alle Regeln; ob Apple die Einreichung danach annimmt, zeigt erst der echte Lauf.

## Kritische Anmerkungen

- Ursache ist nur Hypothese; die Spec liest erst, schreibt dann. Weitere fehlende Pflichtfelder könnten die Einreichung weiter blockieren.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
