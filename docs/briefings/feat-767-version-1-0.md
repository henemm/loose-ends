---
spec_file: docs/specs/tooling/feat-767-version-1-0.md
spec_sha256: a7891d4828e42c11912ac990549d06c52214cf854f818e4dc411ce864edbf82d
spec_frozen_sha256: c38bcdbbf013af329fff100cb1317ee47dbcf9c245a4b8c92c9eb29c5ec32e33
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

- Zusatz: Die Versionsnummer wird nur noch an einer Stelle gepflegt; dafür wurde auch ein bestehender Schutztest gelockert. Nicht verlangt, aber begründet.
- Externe Tester brauchen für 1.0 vermutlich eine neue Beta-Prüfung; Build-Auswahl in App Store Connect bleibt bei Henning.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
