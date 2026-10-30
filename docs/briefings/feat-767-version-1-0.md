---
spec_file: docs/specs/tooling/feat-767-version-1-0.md
spec_sha256: a065557eedd4a02b4eda4a9d89648967ced09c336403d40da939ddfdd8fa29e9
spec_frozen_sha256: ea5bb1ecfbd6032f8046361800a716ee4d1c83f235ec4b0197e1bc2ae2b7b1f6
---

# PO-Briefing: feat-767-version-1-0

- **Spec:** docs/specs/tooling/feat-767-version-1-0.md
- **Issue:** #767
- **Erstellt:** 2026-10-30

## Was gebaut wird

Die App trägt künftig die Versionsnummer 1.0, damit ein Build der vorbereiteten App-Store-Version 1.0 zugeordnet werden kann.

## Definition of Done

Ein TestFlight-Build mit Version 1.0 erscheint in App Store Connect und lässt sich dort der App-Store-Version 1.0 zuordnen.

## Wie geprüft wird

Skripttests und Simulator belegen Version 1.0; ob Apple den Build zuordnen lässt, zeigt erst der TestFlight-Lauf nach dem Merge.

## Kritische Anmerkungen

- Zusatz: Die Versionsnummer wird nur noch an einer Stelle gepflegt; nicht verlangt, aber klein und begründet.
- Externe Tester brauchen für 1.0 vermutlich eine neue Beta-Prüfung; Build-Auswahl in App Store Connect bleibt bei Henning.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
