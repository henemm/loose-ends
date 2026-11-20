---
spec_file: docs/specs/feat-950-titel-getippt.md
spec_sha256: 333926701cf2993685e5f82473fc27d643e23363d816be899b603d0a880d472b
spec_frozen_sha256: 74165bc67499d40104f52527ed267a12b5f494c062bb6475dae6fdd33f32b796
---

# PO-Briefing: feat-950-titel-getippt

- **Spec:** docs/specs/feat-950-titel-getippt.md
- **Issue:** #950
- **Erstellt:** 2026-11-20

## Was gebaut wird

Selbst getippte Aufgaben behalten ihren Titel; die Apple-Intelligence-Modell-Überarbeitung greift dort nicht mehr.

## Definition of Done

Eine getippte Aufgabe, im Erfassungsfenster oder in der Schreibzeile unter „Neu“, zeigt im Simulator ihren eigenen Wortlaut als Titel.

## Wie geprüft wird

Tests belegen, dass getippte Aufgaben ihren Titel behalten, gesprochene weiter verfeinert werden; das echte Modell wird nicht geprüft.

## Kritische Anmerkungen

- Erst diktiert, dann per Tastatur korrigiert zählt als gesprochen: das Modell darf dann den Titel noch ändern.
- Die Titelregel bleibt aktiv: Datumswörter werden entfernt, der Titel auf zwölf Wörter gekürzt.
- Ältere App-Stände auf anderen Geräten können getippte Titel noch verfeinern, bis alle aktualisiert sind.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
